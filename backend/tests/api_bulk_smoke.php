<?php

declare(strict_types=1);

use App\Core\Config;
use App\Core\Database;

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
    fwrite(STDERR, '[FAIL] Bulk smoke tests require a local API and local APP_ENV/database.' . PHP_EOL);
    exit(1);
}

$pdo = Database::connection();
$suffix = bin2hex(random_bytes(5));
$username = 'bulk_test_' . $suffix;
$updatedUsername = $username . '_updated';
$email = $username . '@example.test';
$staffUsername = $username . '_teacher';
$staffEmail = $staffUsername . '@example.test';
$updatedEmail = $updatedUsername . '@example.test';
$password = 'LocalBulkPassword!2026';
$futureSince = (new DateTimeImmutable('today'))->modify('+7 days')->format('Y-m-d');
$userId = null;
$failure = null;

/**
 * @return array{status:int,body:array<string,mixed>}
 */
function bulk_api_request(
    string $method,
    string $path,
    ?array $payload = null,
    ?string $accessToken = null
): array {
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
    $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    curl_close($handle);
    $body = json_decode($rawBody, true, flags: JSON_THROW_ON_ERROR);
    if (!is_array($body)) {
        throw new RuntimeException("Expected JSON from {$path}.");
    }
    return ['status' => $status, 'body' => $body];
}

function bulk_expect(array $response, int $status, string $label): array
{
    if ($response['status'] !== $status) {
        $message = $response['body']['message'] ?? 'unexpected response';
        throw new RuntimeException(
            "{$label}: expected HTTP {$status}, got {$response['status']} ({$message})"
        );
    }
    echo "[OK] {$label}" . PHP_EOL;
    return $response;
}

/**
 * @return array{access_token:string}
 */
function bulk_login(string $identifier, string $password): array
{
    $response = bulk_expect(
        bulk_api_request('POST', 'auth/login', [
            'identifier' => $identifier,
            'password' => $password,
            'device_name' => 'Backend API bulk smoke test',
            'platform' => 'cli',
            'device_model' => 'local',
            'app_version' => '1.0.0+1',
            'device_install_id' => hash('sha256', 'bulk-smoke-' . $identifier),
        ]),
        200,
        "login with {$identifier}"
    );
    $data = $response['body']['data'] ?? null;
    if (!is_array($data) || !is_string($data['access_token'] ?? null)) {
        throw new RuntimeException('Login response contains no access token.');
    }
    return ['access_token' => $data['access_token']];
}

function bulk_row(
    int $rowNumber,
    string $action,
    ?int $id = null,
    string $firstName = '',
    string $lastName = '',
    string $username = '',
    string $email = '',
    string $password = '',
    string $role = '',
    string $sanitaeterSince = ''
): array {
    return [
        'row_number' => $rowNumber,
        'action' => $action,
        'id' => $id,
        'first_name' => $firstName,
        'last_name' => $lastName,
        'username' => $username,
        'email' => $email,
        'temporary_password' => $password,
        'role' => $role,
        'sanitaeter_since' => $sanitaeterSince,
    ];
}

function bulk_cleanup(PDO $pdo, ?int $userId, string $username, string $updatedUsername, string $staffUsername): void
{
    if ($userId === null) {
        $find = $pdo->prepare('SELECT id FROM users WHERE username IN (:username, :updated_username) LIMIT 1');
        $find->execute(['username' => $username, 'updated_username' => $updatedUsername]);
        $found = $find->fetchColumn();
        $userId = $found === false ? null : (int) $found;
    }
    if ($userId !== null) {
        $pdo->prepare('DELETE FROM notification_logs WHERE user_id = :id')->execute(['id' => $userId]);
        $pdo->prepare('DELETE FROM user_devices WHERE user_id = :id')->execute(['id' => $userId]);
        $pdo->prepare(
            'DELETE FROM audit_logs WHERE actor_user_id = :actor_id OR target_user_id = :target_id'
        )->execute(['actor_id' => $userId, 'target_id' => $userId]);
        $pdo->prepare('DELETE FROM users WHERE id = :id')->execute(['id' => $userId]);
    }
    $findStaff = $pdo->prepare('SELECT id FROM users WHERE username = :username LIMIT 1');
    $findStaff->execute(['username' => $staffUsername]);
    $staffId = $findStaff->fetchColumn();
    if ($staffId !== false) {
        $staffId = (int) $staffId;
        $pdo->prepare('DELETE FROM notification_logs WHERE user_id = :id')->execute(['id' => $staffId]);
        $pdo->prepare('DELETE FROM user_devices WHERE user_id = :id')->execute(['id' => $staffId]);
        $pdo->prepare('DELETE FROM audit_logs WHERE actor_user_id = :actor_id OR target_user_id = :target_id')
            ->execute(['actor_id' => $staffId, 'target_id' => $staffId]);
        $pdo->prepare('DELETE FROM users WHERE id = :id')->execute(['id' => $staffId]);
    }
    $pdo->prepare('DELETE FROM user_devices WHERE device_name = :name')
        ->execute(['name' => 'Backend API bulk smoke test']);
}

try {
    $teacher = bulk_login('lehrer', $seedPassword);
    $createRows = [
        bulk_row(
            9,
            'create',
            firstName: 'Bulk',
            lastName: 'Test',
            username: $username,
            email: $email,
            password: $password,
            role: 'sanitaeter',
            sanitaeterSince: $futureSince
        ),
        bulk_row(
            10,
            'create',
            firstName: 'Bulk',
            lastName: 'Lehrer',
            username: $staffUsername,
            email: $staffEmail,
            password: $password,
            role: 'teacher'
        ),
    ];
    $validated = bulk_expect(
        bulk_api_request(
            'POST',
            'users/bulk/validate',
            ['rows' => $createRows],
            $teacher['access_token']
        ),
        200,
        'teacher validates bulk create'
    );
    if (($validated['body']['data']['valid'] ?? null) !== true) {
        throw new RuntimeException('Valid bulk create was rejected.');
    }

    $applied = bulk_expect(
        bulk_api_request(
            'POST',
            'users/bulk/apply',
            ['rows' => $createRows],
            $teacher['access_token']
        ),
        200,
        'teacher applies bulk create'
    );
    if (
        ($applied['body']['data']['applied'] ?? null) !== true
        || (int) ($applied['body']['data']['applied_count'] ?? 0) !== 2
    ) {
        throw new RuntimeException('Valid bulk create was not applied.');
    }

    $find = $pdo->prepare(
        'SELECT id, sanitaeter_since FROM users WHERE school_id = 1 AND username = :username'
    );
    $find->execute(['username' => $username]);
    $created = $find->fetch();
    $userId = (int) ($created['id'] ?? 0);
    if ($userId < 1 || ($created['sanitaeter_since'] ?? null) !== $futureSince) {
        throw new RuntimeException('Bulk-created user or future start date is missing.');
    }
    echo '[OK] bulk create persists future first-aider start date' . PHP_EOL;

    $findStaff = $pdo->prepare(
        'SELECT sanitaeter_since FROM users WHERE school_id = 1 AND username = :username'
    );
    $findStaff->execute(['username' => $staffUsername]);
    if (($findStaff->fetchColumn()) !== null) {
        throw new RuntimeException('Bulk-created teacher retained a sanitary start date.');
    }
    echo '[OK] bulk create stores an empty sanitary date as NULL for teacher accounts' . PHP_EOL;

    $invalidUsername = 'bulk_invalid_' . $suffix;
    $invalidRows = [
        bulk_row(
            10,
            'create',
            firstName: 'Soll',
            lastName: 'Nicht',
            username: $invalidUsername,
            email: $invalidUsername . '@example.test',
            password: $password,
            role: 'sanitaeter',
            sanitaeterSince: $futureSince
        ),
        bulk_row(
            11,
            'create',
            firstName: 'Doppelt',
            lastName: 'Ungültig',
            username: $invalidUsername,
            email: 'other_' . $invalidUsername . '@example.test',
            password: $password,
            role: 'sanitaeter',
            sanitaeterSince: $futureSince
        ),
    ];
    $invalidApply = bulk_expect(
        bulk_api_request(
            'POST',
            'users/bulk/apply',
            ['rows' => $invalidRows],
            $teacher['access_token']
        ),
        200,
        'invalid bulk file returns row validation'
    );
    if (
        ($invalidApply['body']['data']['valid'] ?? null) !== false
        || ($invalidApply['body']['data']['applied'] ?? null) !== false
    ) {
        throw new RuntimeException('Invalid bulk file was not rejected atomically.');
    }
    $notCreated = $pdo->prepare('SELECT COUNT(*) FROM users WHERE username = :username');
    $notCreated->execute(['username' => $invalidUsername]);
    if ((int) $notCreated->fetchColumn() !== 0) {
        throw new RuntimeException('Invalid bulk file applied a partial change.');
    }
    echo '[OK] invalid bulk file is all-or-nothing' . PHP_EOL;

    $updateRows = [
        bulk_row(
            9,
            'update',
            id: $userId,
            firstName: 'Bulk',
            lastName: 'Bearbeitet',
            username: $updatedUsername,
            email: $updatedEmail,
            role: 'sani_leitung'
        ),
    ];
    bulk_expect(
        bulk_api_request(
            'POST',
            'users/bulk/apply',
            ['rows' => $updateRows],
            $teacher['access_token']
        ),
        200,
        'teacher applies bulk update'
    );
    $updated = $pdo->prepare(
        'SELECT role, sanitaeter_since FROM users WHERE id = :id AND username = :username'
    );
    $updated->execute(['id' => $userId, 'username' => $updatedUsername]);
    $updatedUser = $updated->fetch();
    if (
        ($updatedUser['role'] ?? null) !== 'sani_leitung'
        || ($updatedUser['sanitaeter_since'] ?? null) !== $futureSince
    ) {
        throw new RuntimeException('Bulk update failed or changed immutable first-aider date.');
    }
    echo '[OK] bulk update preserves immutable first-aider start date' . PHP_EOL;

    $userSession = bulk_login($updatedUsername, $password);
    bulk_expect(
        bulk_api_request(
            'POST',
            'users/bulk/apply',
            ['rows' => [bulk_row(9, 'deactivate', id: $userId)]],
            $teacher['access_token']
        ),
        200,
        'teacher deactivates account in bulk'
    );
    bulk_expect(
        bulk_api_request('GET', 'auth/session', accessToken: $userSession['access_token']),
        401,
        'bulk deactivation revokes active session'
    );

    bulk_expect(
        bulk_api_request(
            'POST',
            'users/bulk/apply',
            ['rows' => [bulk_row(9, 'reactivate', id: $userId)]],
            $teacher['access_token']
        ),
        200,
        'teacher reactivates account in bulk'
    );
    $reactivatedSession = bulk_login($updatedUsername, $password);
    bulk_expect(
        bulk_api_request(
            'POST',
            'users/bulk/apply',
            ['rows' => [bulk_row(9, 'mark_deletion', id: $userId)]],
            $teacher['access_token']
        ),
        200,
        'teacher marks account for deletion in bulk'
    );
    bulk_expect(
        bulk_api_request('GET', 'auth/session', accessToken: $reactivatedSession['access_token']),
        401,
        'bulk deletion marking revokes active session'
    );
    bulk_expect(
        bulk_api_request('POST', 'auth/logout', accessToken: $teacher['access_token']),
        200,
        'teacher logout'
    );
} catch (Throwable $exception) {
    $failure = $exception;
} finally {
    try {
        bulk_cleanup($pdo, $userId, $username, $updatedUsername, $staffUsername);
        echo '[OK] local bulk-test data cleaned up' . PHP_EOL;
    } catch (Throwable $cleanupException) {
        $failure ??= $cleanupException;
    }
}

if ($failure !== null) {
    fwrite(STDERR, '[FAIL] ' . $failure->getMessage() . PHP_EOL);
    exit(1);
}

echo 'API bulk smoke test passed.' . PHP_EOL;
