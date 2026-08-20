<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Response;
use PDO;

final class AnnouncementModerationService
{
    private const REMOVED_MESSAGE = 'Dieser Inhalt wurde von der Schulmoderation entfernt.';

    /** @var array<int,string> */
    private const REASONS = ['bullying', 'inappropriate', 'privacy', 'spam', 'other'];

    /** @var array<int,string> */
    private const ACTIONS = ['dismiss', 'remove', 'remove_and_deactivate'];

    private AuditLogger $audit;

    public function __construct(
        private readonly PDO $pdo,
        private readonly NotificationService $notifications,
    ) {
        $this->audit = new AuditLogger($pdo);
    }

    /** @param array<string,mixed> $data */
    public function report(AuthContext $auth, int $announcementId, array $data): void
    {
        if ($announcementId < 1) {
            Response::error('Ankündigung wurde nicht gefunden.', 404);
        }
        $reason = trim((string) ($data['reason'] ?? ''));
        if (!in_array($reason, self::REASONS, true)) {
            Response::error('Bitte wähle einen gültigen Meldegrund.', 422);
        }
        $details = trim((string) ($data['details'] ?? ''));
        if (mb_strlen($details) > 500) {
            Response::error('Die zusätzlichen Angaben dürfen höchstens 500 Zeichen haben.', 422);
        }

        $announcement = $this->findAnnouncement($auth->schoolId(), $announcementId);
        if ((string) $announcement['message_type'] !== 'user') {
            Response::error('Systemnachrichten können nicht gemeldet werden.', 422);
        }
        if ((int) $announcement['sender_user_id'] === $auth->userId()) {
            Response::error('Eigene Inhalte können nicht gemeldet werden.', 422);
        }
        if ($announcement['moderated_at'] !== null) {
            Response::error('Dieser Inhalt wurde bereits von der Schulmoderation bearbeitet.', 409);
        }

        $this->pdo->beginTransaction();
        try {
            $statement = $this->pdo->prepare(
                'INSERT INTO announcement_reports
                 (school_id, announcement_id, reporter_user_id, reason, details, status, created_at)
                 VALUES (:school_id, :announcement_id, :reporter_user_id, :reason, :details, "open", UTC_TIMESTAMP())'
            );
            try {
                $statement->execute([
                    'school_id' => $auth->schoolId(),
                    'announcement_id' => $announcementId,
                    'reporter_user_id' => $auth->userId(),
                    'reason' => $reason,
                    'details' => $details === '' ? null : $details,
                ]);
            } catch (\PDOException $exception) {
                if ($exception->getCode() === '23000' || (int) ($exception->errorInfo[1] ?? 0) === 1062) {
                    $this->rollbackAndError('Du hast diesen Inhalt bereits gemeldet.', 409);
                }
                throw $exception;
            }
            $reportId = (int) $this->pdo->lastInsertId();
            $this->audit->log(
                $auth->schoolId(),
                $auth->userId(),
                'announcement.reported',
                (int) $announcement['sender_user_id'],
                'announcement',
                $announcementId,
                ['report_id' => $reportId, 'reason' => $reason]
            );
            $this->pdo->commit();
        } catch (\Throwable $exception) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $exception;
        }

        try {
            $this->notifications->notifyUsersByRole(
                $auth->schoolId(),
                ['sani_leitung', 'teacher'],
                'announcement_reported',
                'Inhalt gemeldet',
                'Eine Ankündigung wartet auf Prüfung.',
                'announcement-report:' . $reportId,
                null,
                $announcementId,
                [$auth->userId()],
                ['route' => 'announcements']
            );
        } catch (\Throwable $exception) {
            error_log('Announcement report notification failed after successful save: ' . $exception->getMessage());
        }
    }

    /** @return array<int,array<string,mixed>> */
    public function list(AuthContext $auth): array
    {
        $this->requireModerator($auth);
        $statement = $this->pdo->prepare(
            'SELECT ar.id, ar.announcement_id, ar.reason, ar.details, ar.status,
                    ar.resolution_action, ar.created_at, ar.resolved_at,
                    CONCAT(reporter.first_name, " ", reporter.last_name) AS reporter_name,
                    a.sender_user_id,
                    CONCAT(sender.first_name, " ", sender.last_name) AS sender_name,
                    sender.role AS sender_role, sender.status AS sender_status,
                    a.message, a.created_at AS announcement_created_at,
                    CASE WHEN a.moderated_at IS NULL THEN 0 ELSE 1 END AS is_moderated,
                    COUNT(aa.id) AS attachment_count,
                    SUM(CASE WHEN aa.id IS NOT NULL AND aa.deleted_at IS NULL THEN 1 ELSE 0 END)
                      AS available_attachment_count
             FROM announcement_reports ar
             JOIN announcements a ON a.id = ar.announcement_id AND a.school_id = ar.school_id
             JOIN users reporter ON reporter.id = ar.reporter_user_id
             JOIN users sender ON sender.id = a.sender_user_id
             LEFT JOIN announcement_attachments aa ON aa.announcement_id = a.id
             WHERE ar.school_id = :school_id AND a.deleted_at IS NULL
             GROUP BY ar.id, ar.announcement_id, ar.reason, ar.details, ar.status,
                      ar.resolution_action, ar.created_at, ar.resolved_at,
                      reporter.first_name, reporter.last_name, a.sender_user_id,
                      sender.first_name, sender.last_name, sender.role, sender.status,
                      a.message, a.created_at, a.moderated_at
             ORDER BY CASE WHEN ar.status = "open" THEN 0 ELSE 1 END,
                      ar.created_at DESC, ar.id DESC
             LIMIT 200'
        );
        $statement->execute(['school_id' => $auth->schoolId()]);
        return array_map(static fn (array $row): array => [
            'id' => (int) $row['id'],
            'announcement_id' => (int) $row['announcement_id'],
            'reason' => (string) $row['reason'],
            'details' => $row['details'],
            'status' => (string) $row['status'],
            'resolution_action' => $row['resolution_action'],
            'created_at' => (string) $row['created_at'],
            'resolved_at' => $row['resolved_at'],
            'reporter_name' => (string) $row['reporter_name'],
            'sender_user_id' => (int) $row['sender_user_id'],
            'sender_name' => (string) $row['sender_name'],
            'sender_role' => (string) $row['sender_role'],
            'sender_status' => (string) $row['sender_status'],
            'message' => (string) $row['message'],
            'announcement_created_at' => (string) $row['announcement_created_at'],
            'is_moderated' => (int) $row['is_moderated'] === 1,
            'attachment_count' => (int) $row['attachment_count'],
            'available_attachment_count' => (int) ($row['available_attachment_count'] ?? 0),
        ], $statement->fetchAll());
    }

    /** @param array<string,mixed> $data */
    public function moderate(AuthContext $auth, int $reportId, array $data): void
    {
        $this->requireModerator($auth);
        if ($reportId < 1) {
            Response::error('Meldung wurde nicht gefunden.', 404);
        }
        $action = trim((string) ($data['action'] ?? ''));
        if (!in_array($action, self::ACTIONS, true)) {
            Response::error('Ungültige Moderationsaktion.', 422);
        }

        $this->pdo->beginTransaction();
        try {
            $statement = $this->pdo->prepare(
                'SELECT ar.id, ar.announcement_id, ar.reason, ar.status, a.sender_user_id
                 FROM announcement_reports ar
                 JOIN announcements a ON a.id = ar.announcement_id AND a.school_id = ar.school_id
                 WHERE ar.id = :id AND ar.school_id = :school_id AND a.deleted_at IS NULL
                 FOR UPDATE'
            );
            $statement->execute(['id' => $reportId, 'school_id' => $auth->schoolId()]);
            $report = $statement->fetch();
            if (!$report) {
                $this->rollbackAndError('Meldung wurde nicht gefunden.', 404);
            }
            if ((string) $report['status'] !== 'open') {
                $this->rollbackAndError('Diese Meldung wurde bereits bearbeitet.', 409);
            }

            $announcementId = (int) $report['announcement_id'];
            $senderUserId = (int) $report['sender_user_id'];
            if ($senderUserId === $auth->userId()) {
                $this->rollbackAndError(
                    'Meldungen zum eigenen Inhalt müssen von einer anderen verantwortlichen Person bearbeitet werden.',
                    403
                );
            }
            if ($action === 'dismiss') {
                $this->pdo->prepare(
                    'UPDATE announcement_reports
                     SET status = "dismissed", resolution_action = "dismiss",
                         resolved_by_user_id = :resolver, resolved_at = UTC_TIMESTAMP()
                     WHERE id = :id'
                )->execute(['resolver' => $auth->userId(), 'id' => $reportId]);
            } else {
                $this->pdo->prepare(
                    'UPDATE announcements
                     SET message = :message, moderated_at = UTC_TIMESTAMP(),
                         moderated_by_user_id = :moderator, moderation_reason = :reason,
                         updated_at = UTC_TIMESTAMP()
                     WHERE id = :id AND school_id = :school_id AND moderated_at IS NULL'
                )->execute([
                    'message' => self::REMOVED_MESSAGE,
                    'moderator' => $auth->userId(),
                    'reason' => (string) $report['reason'],
                    'id' => $announcementId,
                    'school_id' => $auth->schoolId(),
                ]);
                $this->pdo->prepare(
                    'UPDATE announcement_attachments
                     SET content = NULL, deleted_at = COALESCE(deleted_at, UTC_TIMESTAMP())
                     WHERE announcement_id = :announcement_id AND school_id = :school_id'
                )->execute([
                    'announcement_id' => $announcementId,
                    'school_id' => $auth->schoolId(),
                ]);
                $this->pdo->prepare(
                    'UPDATE announcement_reports
                     SET status = "resolved", resolution_action = :action,
                         resolved_by_user_id = :resolver, resolved_at = UTC_TIMESTAMP()
                     WHERE announcement_id = :announcement_id AND school_id = :school_id AND status = "open"'
                )->execute([
                    'action' => $action,
                    'resolver' => $auth->userId(),
                    'announcement_id' => $announcementId,
                    'school_id' => $auth->schoolId(),
                ]);

                if ($action === 'remove_and_deactivate') {
                    $this->pdo->prepare(
                        'UPDATE users
                         SET status = "inactive", deactivated_at = UTC_TIMESTAMP(), updated_at = UTC_TIMESTAMP()
                         WHERE id = :id AND school_id = :school_id AND deleted_at IS NULL
                           AND status <> "pending_deletion"'
                    )->execute(['id' => $senderUserId, 'school_id' => $auth->schoolId()]);
                    $this->pdo->prepare(
                        'UPDATE user_devices SET revoked_at = UTC_TIMESTAMP(), firebase_token = NULL
                         WHERE user_id = :user_id AND revoked_at IS NULL'
                    )->execute(['user_id' => $senderUserId]);
                    $this->audit->log(
                        $auth->schoolId(),
                        $auth->userId(),
                        'user.deactivated_for_content',
                        $senderUserId,
                        'user'
                    );
                }
            }

            $this->audit->log(
                $auth->schoolId(),
                $auth->userId(),
                'announcement.report_resolved',
                $senderUserId,
                'announcement',
                $announcementId,
                ['report_id' => $reportId, 'action' => $action]
            );
            $this->pdo->commit();
        } catch (\Throwable $exception) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $exception;
        }
    }

    /** @return array<string,mixed> */
    private function findAnnouncement(int $schoolId, int $announcementId): array
    {
        $statement = $this->pdo->prepare(
            'SELECT id, sender_user_id, message_type, moderated_at
             FROM announcements
             WHERE id = :id AND school_id = :school_id AND deleted_at IS NULL
             LIMIT 1'
        );
        $statement->execute(['id' => $announcementId, 'school_id' => $schoolId]);
        $announcement = $statement->fetch();
        if (!$announcement) {
            Response::error('Ankündigung wurde nicht gefunden.', 404);
        }
        return $announcement;
    }

    private function requireModerator(AuthContext $auth): void
    {
        if (!$auth->canManageUsers()) {
            Response::error('Nur Sani-Leitung und Lehreraufsicht dürfen Inhaltsmeldungen bearbeiten.', 403);
        }
    }

    private function rollbackAndError(string $message, int $status): never
    {
        if ($this->pdo->inTransaction()) {
            $this->pdo->rollBack();
        }
        Response::error($message, $status);
    }
}
