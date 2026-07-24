<?php

declare(strict_types=1);

namespace App\Services;

use PDO;

final class NotificationService
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly FirebaseMessagingService $firebase,
    ) {
    }

    /**
     * @param array<int,int> $excludeUserIds
     * @param array<string,string> $data
     */
    public function notifyUsersByRole(
        int $schoolId,
        array $roles,
        string $type,
        string $title,
        string $body,
        string $deduplicationKey,
        ?int $dutyDayId = null,
        ?int $announcementId = null,
        array $excludeUserIds = [],
        array $data = [],
    ): void {
        $rolePlaceholders = implode(',', array_fill(0, count($roles), '?'));
        $sql = "SELECT u.id AS user_id, d.firebase_token
                FROM users u
                JOIN user_devices d ON d.user_id = u.id
                WHERE u.school_id = ? AND u.status = 'active' AND d.revoked_at IS NULL
                  AND d.firebase_token IS NOT NULL AND u.role IN ({$rolePlaceholders})";
        $params = array_merge([$schoolId], $roles);
        if ($excludeUserIds !== []) {
            $sql .= ' AND u.id NOT IN (' . implode(',', array_fill(0, count($excludeUserIds), '?')) . ')';
            $params = array_merge($params, $excludeUserIds);
        }
        $statement = $this->pdo->prepare($sql);
        $statement->execute($params);
        foreach ($statement->fetchAll() as $row) {
            $this->send(
                $schoolId,
                (int) $row['user_id'],
                (string) $row['firebase_token'],
                $type,
                $title,
                $body,
                $deduplicationKey . ':' . $row['user_id'],
                $dutyDayId,
                $announcementId,
                $data
            );
        }
    }

    /**
     * @param array<string,string> $data
     */
    public function notifyUser(
        int $schoolId,
        int $userId,
        string $type,
        string $title,
        string $body,
        string $deduplicationKey,
        ?int $dutyDayId = null,
        array $data = [],
    ): void {
        $statement = $this->pdo->prepare(
            'SELECT firebase_token FROM user_devices
             WHERE user_id = :user_id AND revoked_at IS NULL AND firebase_token IS NOT NULL'
        );
        $statement->execute(['user_id' => $userId]);
        foreach ($statement->fetchAll() as $row) {
            $this->send(
                $schoolId,
                $userId,
                (string) $row['firebase_token'],
                $type,
                $title,
                $body,
                $deduplicationKey . ':' . $userId,
                $dutyDayId,
                null,
                $data
            );
        }
    }

    /**
     * @param array<string,string> $data
     */
    private function send(
        int $schoolId,
        int $userId,
        string $token,
        string $type,
        string $title,
        string $body,
        string $deduplicationKey,
        ?int $dutyDayId,
        ?int $announcementId,
        array $data,
    ): void {
        if ($this->wasSent($deduplicationKey)) {
            return;
        }
        $data['notification_type'] = $type;
        if ($dutyDayId !== null) {
            $data['duty_day_id'] = (string) $dutyDayId;
        }
        if ($announcementId !== null) {
            $data['announcement_id'] = (string) $announcementId;
        }
        $status = 'queued';
        try {
            $status = $this->firebase->sendToToken($token, $title, $body, $data);
        } catch (\Throwable $exception) {
            error_log('FCM send failed: ' . $exception->getMessage());
            $status = 'failed';
        }

        $statement = $this->pdo->prepare(
            'INSERT INTO notification_logs
             (school_id, user_id, notification_type, duty_day_id, announcement_id, title, body, sent_at, delivery_status, deduplication_key)
             VALUES (:school_id, :user_id, :type, :duty_day_id, :announcement_id, :title, :body, UTC_TIMESTAMP(), :status, :deduplication_key)'
        );
        $statement->execute([
            'school_id' => $schoolId,
            'user_id' => $userId,
            'type' => $type,
            'duty_day_id' => $dutyDayId,
            'announcement_id' => $announcementId,
            'title' => $title,
            'body' => $body,
            'status' => $status,
            'deduplication_key' => $deduplicationKey,
        ]);
    }

    private function wasSent(string $deduplicationKey): bool
    {
        $statement = $this->pdo->prepare('SELECT id FROM notification_logs WHERE deduplication_key = :key LIMIT 1');
        $statement->execute(['key' => $deduplicationKey]);
        return (bool) $statement->fetchColumn();
    }
}
