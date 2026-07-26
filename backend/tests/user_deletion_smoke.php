<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Core\Database;
use App\Services\PasswordHasher;
use App\Services\UserDeletionService;

$pdo = Database::connection();
$suffix = bin2hex(random_bytes(5));
$schoolId = null;
$userId = null;
$pastDayId = null;
$futureDayId = null;

function deletion_assert(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

try {
    $pdo->prepare('INSERT INTO schools (name, slug) VALUES (:name, :slug)')
        ->execute(['name' => 'Deletion Test', 'slug' => 'deletion-test-' . $suffix]);
    $schoolId = (int) $pdo->lastInsertId();
    $pdo->prepare(
        "INSERT INTO users
         (school_id, first_name, last_name, username, email, password_hash, role,
          sanitaeter_since, status, must_change_password, permanent_deletion_due_at)
         VALUES (:school_id, 'Delete', 'Me', :username, :email, :password_hash,
                 'sanitaeter', '2025-01-01', 'pending_deletion', 0,
                 UTC_TIMESTAMP() - INTERVAL 1 MINUTE)"
    )->execute([
        'school_id' => $schoolId,
        'username' => 'delete-' . $suffix,
        'email' => 'delete-' . $suffix . '@example.invalid',
        'password_hash' => PasswordHasher::hash('temporary-test-password'),
    ]);
    $userId = (int) $pdo->lastInsertId();

    foreach ([['2020-01-02', 'Past'], ['2099-12-30', 'Future']] as [$date, $title]) {
        $pdo->prepare(
            'INSERT INTO duty_days (school_id, duty_date, capacity, is_active, title)
             VALUES (:school_id, :date, 3, 1, :title)'
        )->execute(['school_id' => $schoolId, 'date' => $date, 'title' => $title]);
        $dayId = (int) $pdo->lastInsertId();
        if ($date < '2050-01-01') {
            $pastDayId = $dayId;
        } else {
            $futureDayId = $dayId;
        }
        $pdo->prepare(
            "INSERT INTO duty_assignments (duty_day_id, user_id, status, assignment_type)
             VALUES (:day_id, :user_id, 'planned', 'self')"
        )->execute(['day_id' => $dayId, 'user_id' => $userId]);
    }

    $pdo->prepare(
        "INSERT INTO announcements
         (school_id, sender_user_id, message, message_type, system_type)
         VALUES (:school_id, :user_id, 'Delete Me ist krank.', 'system', 'duty_sick_reported')"
    )->execute(['school_id' => $schoolId, 'user_id' => $userId]);
    $announcementId = (int) $pdo->lastInsertId();
    $pdo->prepare(
        "INSERT INTO announcement_attachments
         (school_id, uploaded_by_user_id, announcement_id, file_name, mime_type, size_bytes, content)
         VALUES (:school_id, :user_id, :announcement_id, 'private.png', 'image/png', 4, :content)"
    )->execute([
        'school_id' => $schoolId,
        'user_id' => $userId,
        'announcement_id' => $announcementId,
        'content' => 'data',
    ]);
    $pdo->prepare(
        "INSERT INTO user_devices
         (user_id, refresh_token_hash, device_name, platform, expires_at)
         VALUES (:user_id, :hash, 'Deletion test', 'cli', UTC_TIMESTAMP() + INTERVAL 1 DAY)"
    )->execute(['user_id' => $userId, 'hash' => hash('sha256', $suffix)]);
    $pdo->prepare(
        "INSERT INTO login_attempts (identifier, ip_address, success)
         VALUES (:identifier, '127.0.0.1', 1)"
    )->execute(['identifier' => 'delete-' . $suffix]);

    $service = new UserDeletionService($pdo);
    deletion_assert($service->processDue() === 1, 'Due user was not processed exactly once.');

    $user = $pdo->query("SELECT * FROM users WHERE id = {$userId}")->fetch();
    deletion_assert($user['status'] === 'deleted', 'User status was not deleted.');
    deletion_assert($user['first_name'] === 'Gelöschter' && $user['last_name'] === 'Nutzer', 'Name was not anonymized.');
    deletion_assert($user['sanitaeter_since'] === null, 'Sanitary start date was retained.');
    deletion_assert($user['deleted_at'] !== null && $user['permanent_deletion_due_at'] === null, 'Deletion timestamps are wrong.');

    $attachment = $pdo->query(
        "SELECT file_name, size_bytes, content, deleted_at FROM announcement_attachments WHERE announcement_id = {$announcementId}"
    )->fetch();
    deletion_assert($attachment['file_name'] === 'Gelöschter Anhang', 'Attachment metadata was retained.');
    deletion_assert((int) $attachment['size_bytes'] === 0 && $attachment['content'] === null, 'Attachment bytes were retained.');
    deletion_assert($attachment['deleted_at'] !== null, 'Attachment tombstone is missing.');

    $message = (string) $pdo->query("SELECT message FROM announcements WHERE id = {$announcementId}")->fetchColumn();
    deletion_assert(str_contains($message, 'Gelöschter Nutzer'), 'System message still names the user.');
    deletion_assert((int) $pdo->query("SELECT COUNT(*) FROM user_devices WHERE user_id = {$userId}")->fetchColumn() === 0, 'Devices were retained.');
    deletion_assert((int) $pdo->query("SELECT COUNT(*) FROM login_attempts WHERE identifier = 'delete-{$suffix}'")->fetchColumn() === 0, 'Login attempts were retained.');
    deletion_assert((string) $pdo->query("SELECT status FROM duty_assignments WHERE duty_day_id = {$futureDayId}")->fetchColumn() === 'admin_removed', 'Future duty remained planned.');
    deletion_assert((string) $pdo->query("SELECT status FROM duty_assignments WHERE duty_day_id = {$pastDayId}")->fetchColumn() === 'planned', 'Historical duty was destroyed.');
    deletion_assert($service->processDue() === 0, 'Deletion processing is not idempotent.');

    echo "User deletion smoke test passed.\n";
} finally {
    if ($schoolId !== null) {
        $pdo->prepare('DELETE FROM audit_logs WHERE school_id = :school_id')->execute(['school_id' => $schoolId]);
        $pdo->prepare('DELETE FROM notification_logs WHERE school_id = :school_id')->execute(['school_id' => $schoolId]);
        $pdo->prepare('DELETE FROM announcement_attachments WHERE school_id = :school_id')->execute(['school_id' => $schoolId]);
        $pdo->prepare('DELETE FROM announcements WHERE school_id = :school_id')->execute(['school_id' => $schoolId]);
        $pdo->prepare('DELETE da FROM duty_assignments da JOIN duty_days dd ON dd.id = da.duty_day_id WHERE dd.school_id = :school_id')
            ->execute(['school_id' => $schoolId]);
        $pdo->prepare('DELETE FROM duty_days WHERE school_id = :school_id')->execute(['school_id' => $schoolId]);
        $pdo->prepare('DELETE FROM users WHERE school_id = :school_id')->execute(['school_id' => $schoolId]);
        $pdo->prepare('DELETE FROM schools WHERE id = :school_id')->execute(['school_id' => $schoolId]);
    }
}
