<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Controllers\AnnouncementController;
use App\Controllers\AuthController;
use App\Controllers\DutyController;
use App\Controllers\MeController;
use App\Controllers\UserController;
use App\Core\Database;
use App\Core\Response;
use App\Core\Router;
use App\Services\AuthService;
use App\Services\DutyService;
use App\Services\FirebaseMessagingService;
use App\Services\NotificationService;
use App\Services\RateLimiter;
use App\Services\UserService;

$pdo = Database::connection();
$firebase = new FirebaseMessagingService();
$notifications = new NotificationService($pdo, $firebase);
$authService = new AuthService($pdo, new RateLimiter($pdo));
$dutyService = new DutyService($pdo, $notifications);
$userService = new UserService($pdo);

$authController = new AuthController($authService);
$meController = new MeController($userService, $authService);
$dutyController = new DutyController($dutyService);
$announcementController = new AnnouncementController($pdo, $notifications);
$userController = new UserController($userService, $authService);

$router = new Router($authService);

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

$router->add('GET', 'duties/upcoming', [$dutyController, 'upcoming']);
$router->add('GET', 'duties/history', [$dutyController, 'history']);
$router->add('GET', 'duties/{date}', [$dutyController, 'details']);
$router->add('POST', 'duties/{date}/self', [$dutyController, 'selfAssign']);
$router->add('DELETE', 'duties/{date}/self', [$dutyController, 'selfCancel']);
$router->add('POST', 'duties/{date}/sick', [$dutyController, 'sickReport']);
$router->add('POST', 'duties/{date}/assignments', [$dutyController, 'adminAssign']);
$router->add('DELETE', 'duties/{date}/assignments/{assignmentId}', [$dutyController, 'adminRemove']);

$router->add('GET', 'announcements', [$announcementController, 'index']);
$router->add('POST', 'announcements', [$announcementController, 'store']);

$router->add('GET', 'users', [$userController, 'index']);
$router->add('POST', 'users', [$userController, 'store']);
$router->add('GET', 'users/{id}', [$userController, 'show']);
$router->add('PATCH', 'users/{id}', [$userController, 'update']);
$router->add('POST', 'users/{id}/deactivate', [$userController, 'deactivate']);
$router->add('POST', 'users/{id}/reactivate', [$userController, 'reactivate']);
$router->add('POST', 'users/{id}/mark-deletion', [$userController, 'markDeletion']);
$router->add('PATCH', 'users/{id}/role', [$userController, 'changeRole']);

try {
    $router->dispatch();
} catch (Throwable $exception) {
    error_log($exception->getMessage());
    Response::error('Ein unerwarteter Serverfehler ist aufgetreten.', 500);
}
