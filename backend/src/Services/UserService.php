<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Response;
use PDO;

final class UserService
{
    private AuthService $authFormatter;
    private AuditLogger $audit;
    private DutyCompletionService $completion;

    public function __construct(private readonly PDO $pdo)
    {
        $this->authFormatter = new AuthService($pdo, new RateLimiter($pdo));
        $this->audit = new AuditLogger($pdo);
        $this->completion = new DutyCompletionService($pdo);
    }

    /**
     * @return array<int,array<string,mixed>>
     */
    public function list(AuthContext $auth): array
    {
        if ($auth->canManageUsers()) {
            $statement = $this->pdo->prepare(
                'SELECT * FROM users WHERE school_id = :school_id AND deleted_at IS NULL ORDER BY last_name, first_name'
            );
            $statement->execute(['school_id' => $auth->schoolId()]);
        } else {
            $statement = $this->pdo->prepare(
                "SELECT * FROM users
                 WHERE school_id = :school_id AND status = 'active' AND deleted_at IS NULL
                 ORDER BY last_name, first_name"
            );
            $statement->execute(['school_id' => $auth->schoolId()]);
        }
        return array_map(fn (array $user) => $this->authFormatter->publicUser($user), $statement->fetchAll());
    }

    /**
     * @return array<string,mixed>
     */
    public function profile(AuthContext $auth, int $userId): array
    {
        if (!$auth->canManageUsers() && $auth->userId() !== $userId) {
            Response::error('Du darfst dieses Profil nicht öffnen.', 403);
        }
        $user = $this->findInSchool($auth->schoolId(), $userId);
        $statistics = in_array((string) $user['role'], ['sanitaeter', 'sani_leitung'], true)
            ? $this->statistics($auth, $userId)
            : null;
        return [
            'user' => $this->authFormatter->publicUser($user),
            'statistics' => $statistics,
        ];
    }

    /**
     * @param array<string,mixed> $data
     */
    public function create(AuthContext $auth, array $data): void
    {
        if (!$auth->canManageUsers()) {
            Response::error('Keine Berechtigung.', 403);
        }
        $role = (string) ($data['role'] ?? 'sanitaeter');
        if (!in_array($role, ['sanitaeter', 'sani_leitung', 'teacher', 'sekretariat'], true)) {
            Response::error('Ungültige Rolle.', 422);
        }
        if ($auth->role() === 'sani_leitung' && $role !== 'sanitaeter') {
            Response::error('Die Sani-Leitung darf neue Konten nur als Schulsanitäter anlegen.', 403);
        }
        $sanitaeterSince = $this->sanitaeterSinceForRole($role, $data['sanitaeter_since'] ?? null);

        $statement = $this->pdo->prepare(
            'INSERT INTO users
             (school_id, first_name, last_name, username, email, password_hash, role, sanitaeter_since,
              status, must_change_password, created_at, updated_at)
             VALUES
             (:school_id, :first_name, :last_name, :username, :email, :password_hash, :role, :sanitaeter_since,
              "active", 1, UTC_TIMESTAMP(), UTC_TIMESTAMP())'
        );
        try {
            $statement->execute([
                'school_id' => $auth->schoolId(),
                'first_name' => trim((string) $data['first_name']),
                'last_name' => trim((string) $data['last_name']),
                'username' => trim((string) $data['username']),
                'email' => mb_strtolower(trim((string) $data['email'])),
                'password_hash' => PasswordHasher::hash((string) $data['temporary_password']),
                'role' => $role,
                'sanitaeter_since' => $sanitaeterSince,
            ]);
        } catch (\PDOException $exception) {
            if ($exception->getCode() === '23000' || (int) ($exception->errorInfo[1] ?? 0) === 1062) {
                Response::error('Benutzername oder E-Mail ist bereits vergeben.', 409);
            }
            throw $exception;
        }
        $this->audit->log(
            $auth->schoolId(),
            $auth->userId(),
            'user.created',
            (int) $this->pdo->lastInsertId(),
            'user'
        );
    }

    public function deactivate(AuthContext $auth, int $userId): void
    {
        $this->requireManagerForTarget($auth, $userId);
        $this->pdo->prepare(
            'UPDATE users SET status = "inactive", deactivated_at = UTC_TIMESTAMP(), updated_at = UTC_TIMESTAMP()
             WHERE id = :id AND school_id = :school_id'
        )->execute(['id' => $userId, 'school_id' => $auth->schoolId()]);
        $this->revokeAllUserDevices($userId);
        $this->audit->log($auth->schoolId(), $auth->userId(), 'user.deactivated', $userId, 'user');
    }

    public function reactivate(AuthContext $auth, int $userId): void
    {
        $this->requireManagerForTarget($auth, $userId);
        $this->pdo->prepare(
            'UPDATE users SET status = "active", deactivated_at = NULL,
                              permanent_deletion_due_at = NULL, updated_at = UTC_TIMESTAMP()
             WHERE id = :id AND school_id = :school_id AND deleted_at IS NULL'
        )->execute(['id' => $userId, 'school_id' => $auth->schoolId()]);
        $this->audit->log($auth->schoolId(), $auth->userId(), 'user.reactivated', $userId, 'user');
    }

    public function markDeletion(AuthContext $auth, int $userId): void
    {
        $this->requireManagerForTarget($auth, $userId);
        $this->pdo->prepare(
            'UPDATE users
             SET status = "pending_deletion", permanent_deletion_due_at = UTC_TIMESTAMP() + INTERVAL 30 DAY,
                 updated_at = UTC_TIMESTAMP()
             WHERE id = :id AND school_id = :school_id'
        )->execute(['id' => $userId, 'school_id' => $auth->schoolId()]);
        $this->revokeAllUserDevices($userId);
        $this->audit->log($auth->schoolId(), $auth->userId(), 'user.marked_for_deletion', $userId, 'user');
    }

    /** @return array<string,mixed> */
    public function dataExport(AuthContext $auth, int $userId): array
    {
        if (!$auth->canManageUsers()) {
            Response::error('Keine Berechtigung.', 403);
        }
        $user = $this->findInSchool($auth->schoolId(), $userId);

        $duties = $this->pdo->prepare(
            'SELECT dd.duty_date, dd.title, da.status, da.assignment_type,
                    da.assigned_at, da.cancelled_at, da.sick_reported_at, da.completed_at
             FROM duty_assignments da
             JOIN duty_days dd ON dd.id = da.duty_day_id
             WHERE da.user_id = :user_id AND dd.school_id = :school_id
             ORDER BY dd.duty_date, da.id'
        );
        $duties->execute(['user_id' => $userId, 'school_id' => $auth->schoolId()]);

        $announcements = $this->pdo->prepare(
            'SELECT id, message, message_type, system_type, created_at
             FROM announcements
             WHERE sender_user_id = :user_id AND school_id = :school_id AND deleted_at IS NULL
             ORDER BY created_at, id'
        );
        $announcements->execute(['user_id' => $userId, 'school_id' => $auth->schoolId()]);

        $attachments = $this->pdo->prepare(
            'SELECT id, announcement_id, file_name, mime_type, size_bytes, created_at,
                    CASE WHEN deleted_at IS NULL AND content IS NOT NULL THEN 0 ELSE 1 END AS is_deleted
             FROM announcement_attachments
             WHERE uploaded_by_user_id = :user_id AND school_id = :school_id
             ORDER BY created_at, id'
        );
        $attachments->execute(['user_id' => $userId, 'school_id' => $auth->schoolId()]);

        $submittedReports = $this->pdo->prepare(
            'SELECT announcement_id, reason, details, status, resolution_action,
                    created_at, resolved_at
             FROM announcement_reports
             WHERE reporter_user_id = :user_id AND school_id = :school_id
             ORDER BY created_at, id'
        );
        $submittedReports->execute(['user_id' => $userId, 'school_id' => $auth->schoolId()]);

        $reportsAboutContent = $this->pdo->prepare(
            'SELECT ar.announcement_id, ar.reason, ar.details, ar.status,
                    ar.resolution_action, ar.created_at, ar.resolved_at
             FROM announcement_reports ar
             JOIN announcements a ON a.id = ar.announcement_id AND a.school_id = ar.school_id
             WHERE a.sender_user_id = :user_id AND ar.school_id = :school_id
             ORDER BY ar.created_at, ar.id'
        );
        $reportsAboutContent->execute(['user_id' => $userId, 'school_id' => $auth->schoolId()]);

        $devices = $this->pdo->prepare(
            'SELECT device_name, platform, device_model, app_version, created_at,
                    last_active_at, revoked_at, expires_at
             FROM user_devices WHERE user_id = :user_id ORDER BY created_at, id'
        );
        $devices->execute(['user_id' => $userId]);

        $audits = $this->pdo->prepare(
            'SELECT action, target_type, target_id, created_at
             FROM audit_logs
             WHERE school_id = :school_id AND (actor_user_id = :actor_id OR target_user_id = :target_id)
             ORDER BY created_at, id'
        );
        $audits->execute([
            'school_id' => $auth->schoolId(),
            'actor_id' => $userId,
            'target_id' => $userId,
        ]);

        $this->audit->log($auth->schoolId(), $auth->userId(), 'user.data_exported', $userId, 'user');

        return [
            'exported_at' => gmdate('c'),
            'school_id' => $auth->schoolId(),
            'user' => [
                'id' => (int) $user['id'],
                'first_name' => $user['first_name'],
                'last_name' => $user['last_name'],
                'username' => $user['username'],
                'email' => $user['email'],
                'role' => $user['role'],
                'sanitaeter_since' => $user['sanitaeter_since'],
                'status' => $user['status'],
                'created_at' => $user['created_at'],
                'updated_at' => $user['updated_at'],
                'deactivated_at' => $user['deactivated_at'],
                'permanent_deletion_due_at' => $user['permanent_deletion_due_at'],
            ],
            'duty_assignments' => $duties->fetchAll(),
            'announcements' => $announcements->fetchAll(),
            'attachment_metadata' => $attachments->fetchAll(),
            'content_reports_submitted' => $submittedReports->fetchAll(),
            'content_reports_about_own_announcements' => $reportsAboutContent->fetchAll(),
            'attachment_files_in_archive' => true,
            'device_metadata' => $devices->fetchAll(),
            'relevant_audit_events' => $audits->fetchAll(),
            'excluded_secrets' => [
                'password_hashes',
                'access_tokens',
                'refresh_token_hashes',
                'firebase_tokens',
            ],
        ];
    }

    /** @return array{path:string,file_name:string} */
    public function dataExportArchive(AuthContext $auth, int $userId): array
    {
        $manifest = $this->dataExport($auth, $userId);
        $path = tempnam(sys_get_temp_dir(), 'ssd-data-export-');
        if ($path === false) {
            throw new \RuntimeException('Could not prepare data export.');
        }
        $zip = new \ZipArchive();
        if ($zip->open($path, \ZipArchive::OVERWRITE) !== true) {
            @unlink($path);
            throw new \RuntimeException('Could not create data export.');
        }
        try {
            $zip->addFromString(
                'datenauskunft.json',
                json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR)
            );
            $statement = $this->pdo->prepare(
                'SELECT id, file_name, mime_type, content
                 FROM announcement_attachments
                 WHERE uploaded_by_user_id = :user_id AND school_id = :school_id
                   AND deleted_at IS NULL AND content IS NOT NULL
                 ORDER BY id'
            );
            $statement->execute(['user_id' => $userId, 'school_id' => $auth->schoolId()]);
            foreach ($statement->fetchAll() as $row) {
                $safeName = preg_replace('/[^A-Za-z0-9._-]/u', '_', (string) $row['file_name']) ?: 'attachment';
                $content = $row['content'];
                if (is_resource($content)) {
                    $content = stream_get_contents($content);
                }
                $zip->addFromString('anhaenge/' . (int) $row['id'] . '-' . $safeName, (string) $content);
            }
        } finally {
            $zip->close();
        }
        return [
            'path' => $path,
            'file_name' => 'SSD-Manager-Datenauskunft-' . $userId . '.zip',
        ];
    }

    public function changeRole(AuthContext $auth, int $userId, string $role): void
    {
        if (!$auth->canManageRoles()) {
            Response::error('Du darfst Rollen nicht verwalten.', 403);
        }
        if ($auth->userId() === $userId) {
            Response::error('Die eigene Rolle kann nicht geändert werden.', 403);
        }
        if (!in_array($role, ['sanitaeter', 'sani_leitung'], true)) {
            Response::error('Die Rolle kann nur zwischen Schulsanitäter und Sani-Leitung gewechselt werden.', 422);
        }
        $target = $this->findInSchool($auth->schoolId(), $userId);
        if (!in_array((string) $target['role'], ['sanitaeter', 'sani_leitung'], true)) {
            Response::error('Die Rolle von Lehreraufsicht und Sekretariat kann hier nicht geändert werden.', 403);
        }
        $this->pdo->prepare(
            'UPDATE users SET role = :role, updated_at = UTC_TIMESTAMP()
             WHERE id = :id AND school_id = :school_id'
        )->execute([
            'role' => $role,
            'id' => $userId,
            'school_id' => $auth->schoolId(),
        ]);
        $this->audit->log($auth->schoolId(), $auth->userId(), 'user.role_changed', $userId, 'user', null, [
            'role' => $role,
        ]);
    }

    /**
     * @return array<string,mixed>
     */
    public function statistics(AuthContext $auth, int $userId): array
    {
        if (!$auth->canManageUsers() && $auth->userId() !== $userId) {
            Response::error('Keine Berechtigung für diese Statistik.', 403);
        }
        $this->findInSchool($auth->schoolId(), $userId);
        $this->completion->markPastPlannedAsCompleted($auth->schoolId(), $userId);
        $statement = $this->pdo->prepare(
            'SELECT da.status, dd.duty_date
             FROM duty_assignments da
             JOIN duty_days dd ON dd.id = da.duty_day_id
             WHERE da.user_id = :user_id AND dd.school_id = :school_id
             ORDER BY dd.duty_date DESC'
        );
        $statement->execute([
            'user_id' => $userId,
            'school_id' => $auth->schoolId(),
        ]);

        $completed = [];
        $upcoming = [];
        $sickCount = 0;
        $today = new \DateTimeImmutable('today', new \DateTimeZone('Europe/Berlin'));
        foreach ($statement->fetchAll() as $row) {
            $date = (string) $row['duty_date'];
            if ($row['status'] === 'completed') {
                $completed[] = $date;
            }
            if ($row['status'] === 'planned' && new \DateTimeImmutable($date) >= $today) {
                $upcoming[] = $date;
            }
            if ($row['status'] === 'sick_reported') {
                $sickCount++;
            }
        }

        return [
            'completed_count' => count($completed),
            'upcoming_count' => count($upcoming),
            'sick_count' => $sickCount,
            'completed_dates' => $completed,
            'upcoming_dates' => $upcoming,
        ];
    }

    /**
     * @return array<int,array<string,mixed>>
     */
    public function devices(AuthContext $auth): array
    {
        $statement = $this->pdo->prepare(
            'SELECT id, device_name, platform, device_model, app_version, created_at, last_active_at
             FROM user_devices
             WHERE user_id = :user_id AND revoked_at IS NULL
             ORDER BY last_active_at DESC'
        );
        $statement->execute(['user_id' => $auth->userId()]);
        return array_map(function (array $row) use ($auth): array {
            return [
                'id' => (int) $row['id'],
                'device_name' => $row['device_name'],
                'platform' => $row['platform'],
                'device_model' => $row['device_model'],
                'app_version' => $row['app_version'],
                'created_at' => $row['created_at'],
                'last_active_at' => $row['last_active_at'],
                'is_current' => (int) $row['id'] === $auth->deviceId(),
            ];
        }, $statement->fetchAll());
    }

    /**
     * @return array<string,mixed>
     */
    private function findInSchool(int $schoolId, int $userId): array
    {
        $statement = $this->pdo->prepare(
            'SELECT * FROM users WHERE id = :id AND school_id = :school_id AND deleted_at IS NULL LIMIT 1'
        );
        $statement->execute(['id' => $userId, 'school_id' => $schoolId]);
        $user = $statement->fetch();
        if (!$user) {
            Response::error('Nutzer wurde nicht gefunden.', 404);
        }
        return $user;
    }

    private function requireManagerForTarget(AuthContext $auth, int $userId): void
    {
        if (!$auth->canManageUsers()) {
            Response::error('Keine Berechtigung.', 403);
        }
        if ($auth->userId() === $userId) {
            Response::error('Diese Aktion ist für den eigenen Account nicht erlaubt.', 403);
        }
        $this->findInSchool($auth->schoolId(), $userId);
    }

    private function revokeAllUserDevices(int $userId): void
    {
        $this->pdo->prepare(
            'UPDATE user_devices SET revoked_at = UTC_TIMESTAMP(), firebase_token = NULL
            WHERE user_id = :user_id AND revoked_at IS NULL'
        )->execute(['user_id' => $userId]);
    }

    private function sanitaeterSinceForRole(string $role, mixed $value): ?string
    {
        if (!in_array($role, ['sanitaeter', 'sani_leitung'], true)) {
            return null;
        }
        if (!is_string($value) || trim($value) === '') {
            Response::error('Bitte gib an, seit wann die Person Schulsanitäter ist.', 422);
        }
        $value = trim($value);
        $date = \DateTimeImmutable::createFromFormat('!Y-m-d', $value);
        $errors = \DateTimeImmutable::getLastErrors();
        if (
            $date === false
            || ($errors !== false && ($errors['warning_count'] > 0 || $errors['error_count'] > 0))
            || $date->format('Y-m-d') !== $value
        ) {
            Response::error('Das Datum „Sanitäter seit“ ist ungültig.', 422);
        }
        return $value;
    }
}
