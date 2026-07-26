<?php

declare(strict_types=1);

namespace App\Services;

use PDO;

final class UserDeletionService
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function processDue(): int
    {
        $statement = $this->pdo->query(
            "SELECT id FROM users
             WHERE status = 'pending_deletion'
               AND deleted_at IS NULL
               AND permanent_deletion_due_at IS NOT NULL
               AND permanent_deletion_due_at <= UTC_TIMESTAMP()
             ORDER BY id"
        );
        $processed = 0;
        foreach ($statement->fetchAll(PDO::FETCH_COLUMN) as $userId) {
            if ($this->anonymize((int) $userId)) {
                $processed++;
            }
        }
        return $processed;
    }

    public function anonymize(int $userId): bool
    {
        $this->pdo->beginTransaction();
        try {
            $statement = $this->pdo->prepare(
                "SELECT * FROM users
                 WHERE id = :id AND status = 'pending_deletion' AND deleted_at IS NULL
                   AND permanent_deletion_due_at IS NOT NULL
                   AND permanent_deletion_due_at <= UTC_TIMESTAMP()
                 FOR UPDATE"
            );
            $statement->execute(['id' => $userId]);
            $user = $statement->fetch();
            if (!$user) {
                $this->pdo->rollBack();
                return false;
            }

            $schoolId = (int) $user['school_id'];
            $fullName = trim((string) $user['first_name'] . ' ' . (string) $user['last_name']);
            $username = (string) $user['username'];
            $email = (string) $user['email'];

            $this->pdo->prepare(
                "UPDATE duty_assignments da
                 JOIN duty_days dd ON dd.id = da.duty_day_id
                 SET da.status = 'admin_removed', da.cancelled_at = UTC_TIMESTAMP(), da.updated_at = UTC_TIMESTAMP()
                 WHERE da.user_id = :user_id AND dd.duty_date >= UTC_DATE() AND da.status = 'planned'"
            )->execute(['user_id' => $userId]);

            $this->pdo->prepare(
                'DELETE FROM announcement_attachments
                 WHERE uploaded_by_user_id = :user_id AND announcement_id IS NULL'
            )->execute(['user_id' => $userId]);
            $this->pdo->prepare(
                "UPDATE announcement_attachments
                 SET file_name = 'Gelöschter Anhang', mime_type = 'application/octet-stream',
                     size_bytes = 0, content = NULL, deleted_at = COALESCE(deleted_at, UTC_TIMESTAMP())
                 WHERE uploaded_by_user_id = :user_id AND announcement_id IS NOT NULL"
            )->execute(['user_id' => $userId]);

            foreach (array_filter(array_unique([$fullName, $username])) as $identifier) {
                $this->pdo->prepare(
                    "UPDATE announcements
                     SET message = REPLACE(message, :identifier, 'Gelöschter Nutzer'), updated_at = UTC_TIMESTAMP()
                     WHERE school_id = :school_id AND sender_user_id = :user_id AND message_type = 'system'"
                )->execute([
                    'identifier' => $identifier,
                    'school_id' => $schoolId,
                    'user_id' => $userId,
                ]);
            }

            $this->pdo->prepare('DELETE FROM user_devices WHERE user_id = :user_id')
                ->execute(['user_id' => $userId]);
            $this->pdo->prepare(
                'DELETE FROM login_attempts WHERE identifier IN (:username, :email)'
            )->execute(['username' => $username, 'email' => $email]);
            $this->pdo->prepare('DELETE FROM notification_logs WHERE user_id = :user_id')
                ->execute(['user_id' => $userId]);
            foreach (array_filter(array_unique([$fullName, $username])) as $identifier) {
                $this->pdo->prepare(
                    "UPDATE notification_logs
                     SET title = REPLACE(title, :title_identifier, 'Gelöschter Nutzer'),
                         body = REPLACE(body, :body_identifier, 'Gelöschter Nutzer')
                     WHERE school_id = :school_id"
                )->execute([
                    'title_identifier' => $identifier,
                    'body_identifier' => $identifier,
                    'school_id' => $schoolId,
                ]);
            }
            $this->pdo->prepare(
                'UPDATE audit_logs SET actor_user_id = NULL, metadata_json = NULL
                 WHERE actor_user_id = :user_id'
            )->execute(['user_id' => $userId]);
            $this->pdo->prepare(
                'UPDATE audit_logs SET target_user_id = NULL, metadata_json = NULL
                 WHERE target_user_id = :user_id'
            )->execute(['user_id' => $userId]);

            $this->pdo->prepare(
                "UPDATE users
                 SET first_name = 'Gelöschter', last_name = 'Nutzer',
                     username = :username, email = :email, password_hash = :password_hash,
                     status = 'deleted', must_change_password = 0, sanitaeter_since = NULL,
                     deactivated_at = COALESCE(deactivated_at, UTC_TIMESTAMP()),
                     deleted_at = UTC_TIMESTAMP(), permanent_deletion_due_at = NULL,
                     updated_at = UTC_TIMESTAMP()
                 WHERE id = :id AND school_id = :school_id"
            )->execute([
                'username' => 'deleted-' . $userId,
                'email' => 'deleted-' . $userId . '@invalid.local',
                'password_hash' => PasswordHasher::hash(bin2hex(random_bytes(32))),
                'id' => $userId,
                'school_id' => $schoolId,
            ]);

            $this->pdo->prepare(
                "INSERT INTO audit_logs
                 (school_id, actor_user_id, action, target_user_id, target_type, target_id, metadata_json, created_at)
                 VALUES (:school_id, NULL, 'user.anonymized', NULL, 'user', :target_id, NULL, UTC_TIMESTAMP())"
            )->execute(['school_id' => $schoolId, 'target_id' => $userId]);

            $this->pdo->commit();
            return true;
        } catch (\Throwable $exception) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $exception;
        }
    }

    /** @return array<string,int> */
    public function deleteExpiredOperationalLogs(): array
    {
        $login = $this->pdo->exec(
            'DELETE FROM login_attempts WHERE attempted_at < (UTC_TIMESTAMP() - INTERVAL 90 DAY)'
        );
        $notifications = $this->pdo->exec(
            'DELETE FROM notification_logs WHERE sent_at < (UTC_TIMESTAMP() - INTERVAL 90 DAY)'
        );
        $audit = $this->pdo->exec(
            'DELETE FROM audit_logs WHERE created_at < (UTC_TIMESTAMP() - INTERVAL 12 MONTH)'
        );
        return [
            'login_attempts' => (int) $login,
            'notification_logs' => (int) $notifications,
            'audit_logs' => (int) $audit,
        ];
    }
}
