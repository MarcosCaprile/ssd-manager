<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Controllers\AnnouncementController;
use App\Controllers\AuthController;
use App\Controllers\BackupController;
use App\Controllers\DutyController;
use App\Controllers\MeController;
use App\Controllers\UserController;
use App\Core\Database;
use App\Core\Response;
use App\Core\Router;
use App\Services\AnnouncementAttachmentService;
use App\Services\AnnouncementModerationService;
use App\Services\AuthService;
use App\Services\DatabaseBackupService;
use App\Services\FtpsBackupStorage;
use App\Services\DutyService;
use App\Services\FirebaseMessagingService;
use App\Services\NotificationService;
use App\Services\RateLimiter;
use App\Services\UserService;
use App\Services\UserBulkService;

$pdo = Database::connection();
$firebase = new FirebaseMessagingService();
$notifications = new NotificationService($pdo, $firebase);
$authService = new AuthService($pdo, new RateLimiter($pdo));
$dutyService = new DutyService($pdo, $notifications);
$userService = new UserService($pdo);
$userBulkService = new UserBulkService($pdo);
$attachmentService = new AnnouncementAttachmentService($pdo);
$announcementModerationService = new AnnouncementModerationService($pdo, $notifications);

$authController = new AuthController($authService);
$meController = new MeController($userService, $authService, $attachmentService);
$dutyController = new DutyController($dutyService);
$announcementController = new AnnouncementController(
    $pdo,
    $notifications,
    $attachmentService,
    $announcementModerationService
);
$userController = new UserController($userService, $authService, $userBulkService);
$backupController = new BackupController($pdo, new DatabaseBackupService($pdo, new FtpsBackupStorage()));

$router = new Router($authService);

$router->add('GET', 'health', static function (): never {
    Response::json(['status' => 'ok']);
}, false);
$router->add('GET', 'ops/backup/run', [$backupController, 'run'], false);
$router->add('GET', 'ops/backup/status', [$backupController, 'status'], false);

$router->add('POST', 'auth/login', [$authController, 'login'], false);
$router->add('POST', 'auth/refresh', [$authController, 'refresh'], false);
$router->add('POST', 'auth/logout', [$authController, 'logout']);
$router->add('GET', 'auth/session', [$authController, 'session']);
$router->add('POST', 'auth/device-token', [$authController, 'deviceToken']);
$router->add('POST', 'auth/password', [$authController, 'changePassword']);

$router->add('GET', 'me', [$meController, 'profile']);
$router->add('GET', 'me/statistics', [$meController, 'statistics']);
$router->add('GET', 'me/devices', [$meController, 'devices']);
$router->add('DELETE', 'me/devices', [$meController, 'revokeOtherDevices']);
$router->add('DELETE', 'me/devices/{id}', [$meController, 'revokeDevice']);
$router->add('GET', 'me/attachments', [$meController, 'attachments']);
$router->add('DELETE', 'me/attachments/{id}', [$meController, 'deleteAttachment']);

$router->add('GET', 'duties/upcoming', [$dutyController, 'upcoming']);
$router->add('GET', 'duties/history', [$dutyController, 'history']);
$router->add('POST', 'duties', [$dutyController, 'create']);
$router->add('POST', 'duties/closures', [$dutyController, 'createClosure']);
$router->add('POST', 'duties/closures/reset', [$dutyController, 'resetClosure']);
$router->add('PATCH', 'duties/{date}', [$dutyController, 'update']);
$router->add('POST', 'duties/{date}/reset', [$dutyController, 'reset']);
$router->add('GET', 'duties/{date}', [$dutyController, 'details']);
$router->add('POST', 'duties/{date}/self', [$dutyController, 'selfAssign']);
$router->add('DELETE', 'duties/{date}/self', [$dutyController, 'selfCancel']);
$router->add('POST', 'duties/{date}/sick', [$dutyController, 'sickReport']);
$router->add('POST', 'duties/{date}/assignments', [$dutyController, 'adminAssign']);
$router->add('DELETE', 'duties/{date}/assignments/{assignmentId}', [$dutyController, 'adminRemove']);

$router->add('GET', 'announcements', [$announcementController, 'index']);
$router->add('POST', 'announcements', [$announcementController, 'store']);
$router->add('DELETE', 'announcements/{id}', [$announcementController, 'deleteOwn']);
$router->add('POST', 'announcements/attachments', [$announcementController, 'uploadAttachment']);
$router->add('GET', 'announcements/attachments/{id}', [$announcementController, 'downloadAttachment']);
$router->add('POST', 'announcements/{id}/reports', [$announcementController, 'report']);
$router->add('GET', 'announcement-reports', [$announcementController, 'reports']);
$router->add('PATCH', 'announcement-reports/{id}', [$announcementController, 'moderateReport']);

$router->add('GET', 'users', [$userController, 'index']);
$router->add('POST', 'users', [$userController, 'store']);
$router->add('POST', 'users/bulk/validate', [$userController, 'validateBulk']);
$router->add('POST', 'users/bulk/apply', [$userController, 'applyBulk']);
$router->add('GET', 'users/{id}', [$userController, 'show']);
$router->add('PATCH', 'users/{id}', [$userController, 'update']);
$router->add('POST', 'users/{id}/deactivate', [$userController, 'deactivate']);
$router->add('POST', 'users/{id}/reactivate', [$userController, 'reactivate']);
$router->add('POST', 'users/{id}/mark-deletion', [$userController, 'markDeletion']);
$router->add('GET', 'users/{id}/data-export', [$userController, 'dataExport']);
$router->add('GET', 'users/{id}/data-export/archive', [$userController, 'dataExportArchive']);
$router->add('PATCH', 'users/{id}/role', [$userController, 'changeRole']);

try {
    $router->dispatch();
} catch (Throwable $exception) {
    error_log($exception->getMessage());
    Response::error('Ein unerwarteter Serverfehler ist aufgetreten.', 500);
}
