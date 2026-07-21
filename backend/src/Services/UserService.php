<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Response;
use PDO;

final class UserService
{
    private AuthService $authFormatter;
    private AuditLogger $audit;

    public function __construct(private readonly PDO $pdo)
    {
        $this->authFormatter = new AuthService($pdo, new RateLimiter($pdo));
        $this->audit = new AuditLogger($pdo);
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
                   AND role IN ('sanitaeter', 'sani_leitung')
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
        return [
            'user' => $this->authFormatter->publicUser($user),
            'statistics' => $this->statistics($auth, $userId),
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
        if (!in_array($role, ['sanitaeter', 'sani_leitung', 'teacher'], true)) {
            Response::error('Ungültige Rolle.', 422);
        }
        if ($auth->role() === 'sani_leitung' && $role !== 'sanitaeter') {
            Response::error('Die Sani-Leitung darf keine Leitungs- oder Lehrerrolle vergeben.', 403);
        }

        $statement = $this->pdo->prepare(
            'INSERT INTO users
             (school_id, first_name, last_name, username, email, password_hash, role, status, must_change_password, created_at, updated_at)
             VALUES
             (:school_id, :first_name, :last_name, :username, :email, :password_hash, :role, "active", 1, UTC_TIMESTAMP(), UTC_TIMESTAMP())'
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
            'UPDATE users SET status = "active", deactivated_at = NULL, updated_at = UTC_TIMESTAMP()
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

    public function changeRole(AuthContext $auth, int $userId, string $role): void
    {
        if (!$auth->canManageRoles()) {
            Response::error('Nur die Lehreraufsicht darf Rollen verwalten.', 403);
        }
        if ($auth->userId() === $userId) {
            Response::error('Die eigene Rolle kann nicht geändert werden.', 403);
        }
        if (!in_array($role, ['sanitaeter', 'sani_leitung', 'teacher'], true)) {
            Response::error('Ungültige Rolle.', 422);
        }
        $this->findInSchool($auth->schoolId(), $userId);
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
}
