<?php

declare(strict_types=1);

use App\Core\Config;
use App\Core\Database;
use App\Services\DutyRules;

require dirname(__DIR__) . '/src/bootstrap.php';

$baseUrl = rtrim(getenv('SSD_API_TEST_BASE_URL') ?: 'http://127.0.0.1:8080/api/v1', '/');
$seedPassword = getenv('SSD_API_TEST_PASSWORD') ?: 'password';
$host = parse_url($baseUrl, PHP_URL_HOST);
$databaseHost = Config::env('DB_HOST', '127.0.0.1');
if (
    Config::env('APP_ENV') !== 'local'
    || !in_array($host, ['127.0.0.1', 'localhost', '::1'], true)
    || !in_array($databaseHost, ['127.0.0.1', 'localhost', '::1'], true)
) {
    fwrite(STDERR, '[FAIL] Write smoke tests require a local API and local APP_ENV/database.' . PHP_EOL);
    exit(1);
}

$pdo = Database::connection();
$suffix = bin2hex(random_bytes(5));
$testUsername = 'api_test_' . $suffix;
$testEmail = $testUsername . '@example.test';
$testPassword = 'LocalSmokePassword!2026';
$changedPassword = 'ChangedSmokePassword!2026';
$testUserId = null;
$announcementId = null;
$loginAttemptBaseline = (int) $pdo->query('SELECT COALESCE(MAX(id), 0) FROM login_attempts')->fetchColumn();

/**
 * @return array{status:int,body:array<string,mixed>}
 */
function api_request(string $method, string $path, ?array $payload = null, ?string $accessToken = null): array
{
    global $baseUrl;

    $headers = ['Accept: application/json'];
    if ($payload !== null) {
        $headers[] = 'Content-Type: application/json';
    }
    if ($accessToken !== null) {
        $headers[] = 'Authorization: Bearer ' . $accessToken;
    }

    $handle = curl_init($baseUrl . '/' . ltrim($path, '/'));
    curl_setopt_array($handle, [
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_POSTFIELDS => $payload === null ? null : json_encode($payload, JSON_THROW_ON_ERROR),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 10,
    ]);
    $rawBody = curl_exec($handle);
    if ($rawBody === false) {
        throw new RuntimeException('HTTP request failed: ' . curl_error($handle));
    }
    $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    curl_close($handle);

    $body = json_decode($rawBody, true, flags: JSON_THROW_ON_ERROR);
    if (!is_array($body)) {
        throw new RuntimeException('Expected a JSON object from ' . $path);
    }

    return ['status' => $status, 'body' => $body];
}

function expect_status(array $response, int $expected, string $label): array
{
    if ($response['status'] !== $expected) {
        $message = $response['body']['message'] ?? 'unexpected response';
        throw new RuntimeException("{$label}: expected HTTP {$expected}, got {$response['status']} ({$message})");
    }
    echo "[OK] {$label}" . PHP_EOL;
    return $response;
}

/**
 * @return array{access_token:string,refresh_token:string}
 */
function api_login(string $identifier, string $password, string $deviceLabel = ''): array
{
    $deviceName = 'Backend API write smoke test' . ($deviceLabel === '' ? '' : ' ' . $deviceLabel);
    $response = expect_status(api_request('POST', 'auth/login', [
        'identifier' => $identifier,
        'password' => $password,
        'device_name' => $deviceName,
        'platform' => 'cli',
        'device_model' => 'local',
        'app_version' => '1.0.0+1',
        'device_install_id' => hash('sha256', $deviceName),
    ]), 200, "login with {$identifier}");

    $data = $response['body']['data'] ?? null;
    if (!is_array($data) || !is_string($data['access_token'] ?? null) || !is_string($data['refresh_token'] ?? null)) {
        throw new RuntimeException("login with {$identifier}: response contains no token pair");
    }
    return ['access_token' => $data['access_token'], 'refresh_token' => $data['refresh_token']];
}

function find_test_date(DutyRules $rules, bool $insideCancellationWindow): string
{
    $now = new DateTimeImmutable('now', new DateTimeZone(Config::env('SCHOOL_TIMEZONE', 'Europe/Berlin') ?? 'Europe/Berlin'));
    for ($offset = 0; $offset < 14; $offset++) {
        $date = $now->modify("+{$offset} days")->format('Y-m-d');
        if (!$rules->canBook($date, $now)) {
            continue;
        }
        if ($insideCancellationWindow && $rules->canReportSick($date, $now)) {
            return $date;
        }
        if (!$insideCancellationWindow && $rules->canCancelRegularly($date, $now)) {
            return $date;
        }
    }
    throw new RuntimeException('No suitable weekday exists in the 14-day test window.');
}

function assignment_id(array $response, int $userId, string $status): int
{
    $assignments = $response['body']['data']['assignments'] ?? null;
    if (!is_array($assignments)) {
        throw new RuntimeException('Duty details contain no assignments list.');
    }
    foreach ($assignments as $assignment) {
        if ((int) ($assignment['user_id'] ?? 0) === $userId && ($assignment['status'] ?? null) === $status) {
            return (int) $assignment['id'];
        }
    }
    throw new RuntimeException("No {$status} assignment found for test user.");
}

function current_device_id(array $response): int
{
    $devices = $response['body']['data'] ?? null;
    if (!is_array($devices)) {
        throw new RuntimeException('Device response contains no device list.');
    }
    foreach ($devices as $device) {
        if (($device['is_current'] ?? false) === true) {
            return (int) $device['id'];
        }
    }
    throw new RuntimeException('Device response does not identify the current session.');
}

function cleanup(PDO $pdo, ?int $testUserId, ?int $announcementId, int $loginAttemptBaseline, string $testUsername): void
{
    if ($announcementId !== null) {
        $pdo->prepare('DELETE FROM notification_logs WHERE announcement_id = :id')->execute(['id' => $announcementId]);
        $pdo->prepare('DELETE FROM announcements WHERE id = :id')->execute(['id' => $announcementId]);
    }
    if ($testUserId !== null) {
        $pdo->prepare('DELETE FROM notification_logs WHERE user_id = :id')->execute(['id' => $testUserId]);
        $pdo->prepare('DELETE FROM duty_assignments WHERE user_id = :id')->execute(['id' => $testUserId]);
        $pdo->prepare('DELETE FROM audit_logs WHERE actor_user_id = :actor_id OR target_user_id = :target_id')
            ->execute(['actor_id' => $testUserId, 'target_id' => $testUserId]);
        $pdo->prepare('DELETE FROM users WHERE id = :id')->execute(['id' => $testUserId]);
    }
    $pdo->prepare('DELETE FROM user_devices WHERE device_name LIKE :device_name')
        ->execute(['device_name' => 'Backend API write smoke test%']);
    $pdo->prepare(
        'DELETE FROM login_attempts
         WHERE id > :baseline AND identifier IN (:teacher, :lead, :viewer, :test_user)'
    )
        ->execute([
            'baseline' => $loginAttemptBaseline,
            'teacher' => 'lehrer',
            'lead' => 'leitung',
            'viewer' => 'noah',
            'test_user' => $testUsername,
        ]);
}

$failure = null;
try {
    $rules = new DutyRules(Config::env('SCHOOL_TIMEZONE', 'Europe/Berlin') ?? 'Europe/Berlin');
    $regularDate = find_test_date($rules, false);
    $sickDate = find_test_date($rules, true);

    $teacher = api_login('lehrer', $seedPassword);
    $lead = api_login('leitung', $seedPassword);

    expect_status(
        api_request('POST', "duties/{$regularDate}/self", accessToken: $teacher['access_token']),
        403,
        'teacher cannot self-assign to duty'
    );
    expect_status(
        api_request('PATCH', 'users/1/role', ['role' => 'sanitaeter'], $teacher['access_token']),
        403,
        'teacher cannot change own role'
    );
    expect_status(api_request('POST', 'users', [
        'first_name' => 'API',
        'last_name' => 'Test',
        'username' => $testUsername,
        'email' => $testEmail,
        'temporary_password' => $testPassword,
        'role' => 'sanitaeter',
        'sanitaeter_since' => '2024-01-01',
    ], $teacher['access_token']), 201, 'teacher creates test account');

    $findUser = $pdo->prepare('SELECT id FROM users WHERE school_id = 1 AND username = :username');
    $findUser->execute(['username' => $testUsername]);
    $testUserId = (int) $findUser->fetchColumn();
    if ($testUserId < 1) {
        throw new RuntimeException('Created test account was not found in the local database.');
    }

    expect_status(
        api_request('POST', 'users', [
            'first_name' => 'Forbidden',
            'last_name' => 'Teacher',
            'username' => 'forbidden_' . $suffix,
            'email' => 'forbidden_' . $suffix . '@example.test',
            'temporary_password' => $testPassword,
            'role' => 'teacher',
        ], $lead['access_token']),
        403,
        'lead cannot create teacher account'
    );
    expect_status(
        api_request('PATCH', "users/{$testUserId}/role", ['role' => 'sani_leitung'], $lead['access_token']),
        200,
        'lead promotes first-aider to lead'
    );
    expect_status(
        api_request('PATCH', "users/{$testUserId}/role", ['role' => 'sanitaeter'], $lead['access_token']),
        200,
        'lead restores first-aider role'
    );
    expect_status(
        api_request('PATCH', "users/{$testUserId}/role", ['role' => 'sani_leitung'], $teacher['access_token']),
        200,
        'teacher promotes test account'
    );
    expect_status(
        api_request('PATCH', "users/{$testUserId}/role", ['role' => 'sanitaeter'], $teacher['access_token']),
        200,
        'teacher restores test account role'
    );

    $sanitaeter = api_login($testUsername, $testPassword, 'primary');
    expect_status(
        api_request('POST', 'auth/password', [
            'current_password' => 'incorrect-password',
            'new_password' => $changedPassword,
        ], $sanitaeter['access_token']),
        422,
        'password change rejects incorrect current password'
    );
    expect_status(
        api_request('POST', 'auth/password', [
            'current_password' => $testPassword,
            'new_password' => 'too-short',
        ], $sanitaeter['access_token']),
        422,
        'password change rejects short new password'
    );
    $oldPasswordSession = api_login($testUsername, $testPassword, 'old-password');
    expect_status(
        api_request('POST', 'auth/password', [
            'current_password' => $testPassword,
            'new_password' => $changedPassword,
            'revoke_other_devices' => true,
        ], $sanitaeter['access_token']),
        200,
        'first-aider changes password and revokes other devices'
    );
    expect_status(
        api_request('GET', 'auth/session', accessToken: $oldPasswordSession['access_token']),
        401,
        'password change revokes other session'
    );
    expect_status(
        api_request('POST', 'auth/login', [
            'identifier' => $testUsername,
            'password' => $testPassword,
            'device_name' => 'Backend API write smoke test',
            'platform' => 'cli',
        ]),
        401,
        'old password is rejected'
    );

    $currentSession = api_login($testUsername, $changedPassword, 'current');
    $revokedByIdSession = api_login($testUsername, $changedPassword, 'single-revoke');
    $revokedWithOthersSession = api_login($testUsername, $changedPassword, 'bulk-revoke');
    $deviceList = expect_status(
        api_request('GET', 'me/devices', accessToken: $revokedByIdSession['access_token']),
        200,
        'device list identifies active sessions'
    );
    $revokedById = current_device_id($deviceList);
    expect_status(
        api_request('DELETE', "me/devices/{$revokedById}", accessToken: $currentSession['access_token']),
        200,
        'current session revokes another device'
    );
    expect_status(
        api_request('GET', 'auth/session', accessToken: $revokedByIdSession['access_token']),
        401,
        'individually revoked device session is rejected'
    );
    expect_status(
        api_request('DELETE', 'me/devices', accessToken: $currentSession['access_token']),
        200,
        'current session revokes all other devices'
    );
    expect_status(
        api_request('GET', 'auth/session', accessToken: $revokedWithOthersSession['access_token']),
        401,
        'bulk-revoked device session is rejected'
    );
    expect_status(
        api_request('GET', 'auth/session', accessToken: $currentSession['access_token']),
        200,
        'current session remains active after device cleanup'
    );
    $sanitaeter = $currentSession;
    expect_status(
        api_request('GET', 'users/1', accessToken: $sanitaeter['access_token']),
        403,
        'first-aider cannot open another profile'
    );
    expect_status(
        api_request('POST', 'users', [
            'first_name' => 'Forbidden',
            'last_name' => 'Account',
            'username' => 'forbidden_sani_' . $suffix,
            'email' => 'forbidden_sani_' . $suffix . '@example.test',
            'temporary_password' => $testPassword,
            'role' => 'sanitaeter',
            'sanitaeter_since' => '2024-01-01',
        ], $sanitaeter['access_token']),
        403,
        'first-aider cannot create accounts'
    );
    expect_status(
        api_request('POST', "duties/{$regularDate}/assignments", ['user_id' => $testUserId], $sanitaeter['access_token']),
        403,
        'first-aider cannot assign others to duty'
    );

    $announcement = expect_status(
        api_request('POST', 'announcements', ['message' => "API write smoke {$suffix}"], $sanitaeter['access_token']),
        201,
        'first-aider sends announcement'
    );
    $announcementId = (int) ($announcement['body']['data']['id'] ?? 0);
    if ($announcementId < 1) {
        throw new RuntimeException('Announcement response contains no id.');
    }

    expect_status(
        api_request('POST', "duties/{$regularDate}/self", accessToken: $sanitaeter['access_token']),
        201,
        'first-aider self-assigns to duty'
    );
    expect_status(
        api_request('POST', "duties/{$regularDate}/self", accessToken: $sanitaeter['access_token']),
        409,
        'duplicate self-assignment is rejected'
    );
    expect_status(
        api_request('DELETE', "duties/{$regularDate}/self", accessToken: $sanitaeter['access_token']),
        200,
        'first-aider cancels outside 48-hour window'
    );

    expect_status(
        api_request('POST', "duties/{$regularDate}/assignments", ['user_id' => $testUserId], $teacher['access_token']),
        201,
        'teacher assigns first-aider to duty'
    );
    $regularDetails = expect_status(
        api_request('GET', "duties/{$regularDate}", accessToken: $teacher['access_token']),
        200,
        'assigned duty details'
    );
    $regularAssignmentId = assignment_id($regularDetails, $testUserId, 'planned');
    expect_status(
        api_request(
            'DELETE',
            "duties/{$sickDate}/assignments/{$regularAssignmentId}",
            accessToken: $teacher['access_token']
        ),
        404,
        'assignment cannot be removed through a mismatched duty date'
    );
    expect_status(
        api_request(
            'DELETE',
            "duties/{$regularDate}/assignments/{$regularAssignmentId}",
            accessToken: $teacher['access_token']
        ),
        200,
        'teacher removes duty assignment'
    );

    expect_status(
        api_request('POST', "duties/{$sickDate}/assignments", ['user_id' => $testUserId], $teacher['access_token']),
        201,
        'teacher assigns near-term duty'
    );
    expect_status(
        api_request('POST', "duties/{$sickDate}/sick", accessToken: $sanitaeter['access_token']),
        200,
        'first-aider reports sick inside 48-hour window'
    );
    $sickDetails = expect_status(
        api_request('GET', "duties/{$sickDate}", accessToken: $teacher['access_token']),
        200,
        'sick-report duty details'
    );
    assignment_id($sickDetails, $testUserId, 'sick_reported');

    expect_status(
        api_request('POST', "users/{$testUserId}/deactivate", accessToken: $teacher['access_token']),
        200,
        'teacher deactivates account'
    );
    expect_status(
        api_request('GET', 'auth/session', accessToken: $sanitaeter['access_token']),
        401,
        'deactivation revokes account session'
    );
    $inactiveLogin = expect_status(
        api_request('POST', 'auth/login', [
            'identifier' => $testUsername,
            'password' => $changedPassword,
            'device_name' => 'Backend API write smoke test inactive-login',
            'platform' => 'cli',
        ]),
        403,
        'deactivated account cannot log in'
    );
    if (!str_contains(
        (string) ($inactiveLogin['body']['message'] ?? ''),
        'Account wurde deaktiviert'
    )) {
        throw new RuntimeException('Deactivated login does not return the dedicated user guidance.');
    }
    echo '[OK] deactivated login explains who the user should contact' . PHP_EOL;

    $managerUsers = expect_status(
        api_request('GET', 'users', accessToken: $teacher['access_token']),
        200,
        'teacher lists inactive accounts'
    );
    $managerIds = array_map(
        static fn (array $user): int => (int) ($user['id'] ?? 0),
        $managerUsers['body']['data'] ?? []
    );
    if (!in_array($testUserId, $managerIds, true)) {
        throw new RuntimeException('Inactive account is missing from the manager user list.');
    }

    $viewer = api_login('noah', $seedPassword, 'inactive-viewer');
    $viewerUsers = expect_status(
        api_request('GET', 'users', accessToken: $viewer['access_token']),
        200,
        'first-aider lists active school accounts'
    );
    $viewerIds = array_map(
        static fn (array $user): int => (int) ($user['id'] ?? 0),
        $viewerUsers['body']['data'] ?? []
    );
    if (in_array($testUserId, $viewerIds, true)) {
        throw new RuntimeException('Inactive account leaked into the first-aider user list.');
    }
    echo '[OK] inactive accounts are visible only to managers' . PHP_EOL;
    expect_status(
        api_request('POST', 'auth/logout', accessToken: $viewer['access_token']),
        200,
        'inactive-account viewer logout'
    );
    expect_status(
        api_request('POST', "users/{$testUserId}/reactivate", accessToken: $teacher['access_token']),
        200,
        'teacher reactivates account'
    );
    $reactivated = api_login($testUsername, $changedPassword, 'reactivated');
    $sameDeviceBeforeLogout = api_login($testUsername, $changedPassword, 'same-device');
    expect_status(
        api_request('POST', 'auth/logout', accessToken: $sameDeviceBeforeLogout['access_token']),
        200,
        'logout revokes current device session'
    );
    $sameDeviceAfterLogout = api_login($testUsername, $changedPassword, 'same-device');
    $sameDeviceList = expect_status(
        api_request('GET', 'me/devices', accessToken: $sameDeviceAfterLogout['access_token']),
        200,
        'same physical device logs in again'
    );
    $matchingDevices = array_filter(
        $sameDeviceList['body']['data'] ?? [],
        static fn (array $device): bool =>
            ($device['device_name'] ?? null) === 'Backend API write smoke test same-device'
    );
    if (count($matchingDevices) !== 1) {
        throw new RuntimeException('Re-login left duplicate active sessions for the same device.');
    }
    echo '[OK] re-login keeps only one active entry for the same device' . PHP_EOL;
    $reactivated = $sameDeviceAfterLogout;
    expect_status(
        api_request('POST', "users/{$testUserId}/mark-deletion", accessToken: $teacher['access_token']),
        200,
        'teacher marks account for deletion'
    );
    expect_status(
        api_request('GET', 'auth/session', accessToken: $reactivated['access_token']),
        401,
        'deletion marking revokes account session'
    );
    expect_status(
        api_request('POST', 'auth/login', [
            'identifier' => $testUsername,
            'password' => $changedPassword,
            'device_name' => 'Backend API write smoke test',
            'platform' => 'cli',
        ]),
        403,
        'pending-deletion account cannot log in'
    );

    expect_status(api_request('POST', 'auth/logout', accessToken: $teacher['access_token']), 200, 'teacher logout');
    expect_status(api_request('POST', 'auth/logout', accessToken: $lead['access_token']), 200, 'lead logout');
} catch (Throwable $exception) {
    $failure = $exception;
} finally {
    try {
        cleanup($pdo, $testUserId, $announcementId, $loginAttemptBaseline, $testUsername);
        echo '[OK] local write-test data cleaned up' . PHP_EOL;
    } catch (Throwable $cleanupException) {
        $failure ??= $cleanupException;
    }
}

if ($failure !== null) {
    fwrite(STDERR, '[FAIL] ' . $failure->getMessage() . PHP_EOL);
    exit(1);
}

echo 'API write smoke test passed.' . PHP_EOL;
