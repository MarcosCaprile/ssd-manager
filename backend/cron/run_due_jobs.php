<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Core\Database;
use App\Services\DutyService;
use App\Services\AnnouncementAttachmentService;
use App\Services\FirebaseMessagingService;
use App\Services\NotificationService;

$pdo = Database::connection();
$notifications = new NotificationService($pdo, new FirebaseMessagingService());
$duties = new DutyService($pdo, $notifications);
$attachments = new AnnouncementAttachmentService($pdo);

$completed = $duties->markPastPlannedAsCompleted();
$reminders = $duties->send48HourReminders();
$expiredAttachments = $attachments->deleteExpiredUnclaimed();

echo json_encode([
    'completed_assignments' => $completed,
    'reminder_batches' => $reminders,
    'deleted_unclaimed_attachments' => $expiredAttachments,
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . PHP_EOL;
