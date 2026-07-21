<?php

declare(strict_types=1);

use App\Core\Config;
use App\Core\Database;
use App\Services\DutyRules;
use App\Services\PasswordHasher;

require dirname(__DIR__) . '/src/bootstrap.php';

$baseUrls = [
    rtrim(getenv('SSD_API_TEST_BASE_URL_A') ?: 'http://127.0.0.1:8080/api/v1', '/'),
    rtrim(getenv('SSD_API_TEST_BASE_URL_B') ?: 'http://127.0.0.1:8081/api/v1', '/'),
];
$databaseHost = Config::env('DB_HOST', '127.0.0.1');
foreach ($baseUrls as $baseUrl) {
    if (!in_array(parse_url($baseUrl, PHP_URL_HOST), ['127.0.0.1', 'localhost', '::1'], true)) {
        fwrite(STDERR, '[FAIL] Concurrency smoke tests are restricted to local APIs.' . PHP_EOL);
        exit(1);
    }
}
if (Config::env('APP_ENV') !== 'local' || !in_array($databaseHost, ['127.0.0.1', 'localhost', '::1'], true)) {
    fwrite(STDERR, '[FAIL] Concurrency smoke tests require a local APP_ENV/database.' . PHP_EOL);
    exit(1);
}

$pdo = Database::connection();
$suffix = bin2hex(random_bytes(5));
$testUserIds = [];
$testUsernames = [];
$dutyDate = null;
$dutyDayExisted = false;
$loginAttemptBaseline = (int) $pdo->query('SELECT COALESCE(MAX(id), 0) FROM login_attempts')->fetchColumn();

/**
 * @return array{status:int,body:array<string,mixed>}
 */
function http_request(
    string $baseUrl,
    string $method,
    string $path,
    ?array $payload = null,
    ?string $accessToken = null,
): array {
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

function expect_http(array $response, int $expected, string $label): array
{
    if ($response['status'] !== $expected) {
        $message = $response['body']['message'] ?? 'unexpected response';
        throw new RuntimeException("{$label}: expected HTTP {$expected}, got {$response['status']} ({$message})");
    }
    echo "[OK] {$label}" . PHP_EOL;
    return $response;
}

function teacher_token(string $baseUrl): string
{
    $response = expect_http(http_request($baseUrl, 'POST', 'auth/login', [
        'identifier' => 'lehrer',
        'password' => getenv('SSD_API_TEST_PASSWORD') ?: 'password',
        'device_name' => 'Backend API concurrency smoke test',
        'platform' => 'cli',
        'device_model' => 'local',
        'app_version' => '1.0.0+1',
    ]), 200, 'teacher login on ' . parse_url($baseUrl, PHP_URL_PORT));
    $token = $response['body']['data']['access_token'] ?? null;
    if (!is_string($token)) {
        throw new RuntimeException('Teacher login response contains no access token.');
    }
    return $token;
}

/**
 * @param array<int,array{base_url:string,token:string,user_id:int}> $requests
 * @return array<int,array{status:int,body:array<string,mixed>}>
 */
function concurrent_assignments(array $requests, string $date): array
{
    $multiHandle = curl_multi_init();
    $handles = [];
    foreach ($requests as $request) {
        $handle = curl_init($request['base_url'] . "/duties/{$date}/assignments");
        curl_setopt_array($handle, [
            CURLOPT_CUSTOMREQUEST => 'POST',
            CURLOPT_HTTPHEADER => [
                'Accept: application/json',
                'Content-Type: application/json',
                'Authorization: Bearer ' . $request['token'],
            ],
            CURLOPT_POSTFIELDS => json_encode(['user_id' => $request['user_id']], JSON_THROW_ON_ERROR),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 10,
        ]);
        curl_multi_add_handle($multiHandle, $handle);
        $handles[] = $handle;
    }

    do {
        $status = curl_multi_exec($multiHandle, $running);
        if ($running > 0) {
            curl_multi_select($multiHandle, 1.0);
        }
    } while ($running > 0 && $status === CURLM_OK);

    $responses = [];
    foreach ($handles as $handle) {
        $rawBody = curl_multi_getcontent($handle);
        $body = json_decode($rawBody, true, flags: JSON_THROW_ON_ERROR);
        if (!is_array($body)) {
            throw new RuntimeException('Concurrent assignment returned no JSON object.');
        }
        $responses[] = [
            'status' => curl_getinfo($handle, CURLINFO_RESPONSE_CODE),
            'body' => $body,
        ];
        curl_multi_remove_handle($multiHandle, $handle);
        curl_close($handle);
    }
    curl_multi_close($multiHandle);
    return $responses;
}

function cleanup_concurrency_test(
    PDO $pdo,
    array $testUserIds,
    array $testUsernames,
    ?string $dutyDate,
    bool $dutyDayExisted,
    int $loginAttemptBaseline,
): void {
    if ($testUserIds !== []) {
        $placeholders = implode(',', array_fill(0, count($testUserIds), '?'));
        $pdo->prepare("DELETE FROM notification_logs WHERE user_id IN ({$placeholders})")->execute($testUserIds);
        $pdo->prepare("DELETE FROM duty_assignments WHERE user_id IN ({$placeholders})")->execute($testUserIds);
        $pdo->prepare("DELETE FROM audit_logs WHERE target_user_id IN ({$placeholders})")->execute($testUserIds);
        $pdo->prepare("DELETE FROM users WHERE id IN ({$placeholders})")->execute($testUserIds);
    }
    $pdo->prepare('DELETE FROM user_devices WHERE device_name = :device_name')
        ->execute(['device_name' => 'Backend API concurrency smoke test']);
    $identifiers = array_merge(['lehrer'], $testUsernames);
    $identifierPlaceholders = implode(',', array_fill(0, count($identifiers), '?'));
    $pdo->prepare("DELETE FROM login_attempts WHERE id > ? AND identifier IN ({$identifierPlaceholders})")
        ->execute(array_merge([$loginAttemptBaseline], $identifiers));
    if ($dutyDate !== null && !$dutyDayExisted) {
        $pdo->prepare(
            'DELETE FROM duty_days WHERE school_id = 1 AND duty_date = :date
             AND NOT EXISTS (SELECT 1 FROM duty_assignments WHERE duty_day_id = duty_days.id)'
        )->execute(['date' => $dutyDate]);
    }
}

$failure = null;
try {
    $rules = new DutyRules(Config::env('SCHOOL_TIMEZONE', 'Europe/Berlin') ?? 'Europe/Berlin');
    $now = new DateTimeImmutable('now', new DateTimeZone(Config::env('SCHOOL_TIMEZONE', 'Europe/Berlin') ?? 'Europe/Berlin'));
    for ($offset = 3; $offset < 14; $offset++) {
        $candidate = $now->modify("+{$offset} days")->format('Y-m-d');
        if (!$rules->canBook($candidate, $now)) {
            continue;
        }
        $count = $pdo->prepare(
            'SELECT COUNT(*) FROM duty_assignments da
             JOIN duty_days dd ON dd.id = da.duty_day_id
             WHERE dd.school_id = 1 AND dd.duty_date = :date AND da.status = "planned"'
        );
        $count->execute(['date' => $candidate]);
        if ((int) $count->fetchColumn() === 0) {
            $dutyDate = $candidate;
            break;
        }
    }
    if ($dutyDate === null) {
        throw new RuntimeException('No empty weekday is available in the local 14-day window.');
    }
    $existingDay = $pdo->prepare('SELECT id FROM duty_days WHERE school_id = 1 AND duty_date = :date');
    $existingDay->execute(['date' => $dutyDate]);
    $dutyDayExisted = (bool) $existingDay->fetchColumn();

    $insertUser = $pdo->prepare(
        'INSERT INTO users
         (school_id, first_name, last_name, username, email, password_hash, role, status, must_change_password)
         VALUES (1, :first_name, :last_name, :username, :email, :password_hash, "sanitaeter", "active", 1)'
    );
    for ($index = 1; $index <= 4; $index++) {
        $username = "capacity_{$suffix}_{$index}";
        $insertUser->execute([
            'first_name' => 'Capacity',
            'last_name' => "Test {$index}",
            'username' => $username,
            'email' => $username . '@example.test',
            'password_hash' => PasswordHasher::hash('LocalCapacityPassword!2026'),
        ]);
        $testUserIds[] = (int) $pdo->lastInsertId();
        $testUsernames[] = $username;
    }

    $tokens = [teacher_token($baseUrls[0]), teacher_token($baseUrls[1])];
    expect_http(
        http_request($baseUrls[0], 'POST', "duties/{$dutyDate}/assignments", ['user_id' => $testUserIds[0]], $tokens[0]),
        201,
        'first capacity slot is assigned'
    );
    expect_http(
        http_request($baseUrls[0], 'POST', "duties/{$dutyDate}/assignments", ['user_id' => $testUserIds[1]], $tokens[0]),
        201,
        'second capacity slot is assigned'
    );

    $raceResponses = concurrent_assignments([
        ['base_url' => $baseUrls[0], 'token' => $tokens[0], 'user_id' => $testUserIds[2]],
        ['base_url' => $baseUrls[1], 'token' => $tokens[1], 'user_id' => $testUserIds[3]],
    ], $dutyDate);
    $statuses = array_column($raceResponses, 'status');
    sort($statuses);
    if ($statuses !== [201, 409]) {
        throw new RuntimeException(
            'Concurrent final-slot requests did not produce exactly HTTP 201 and 409: '
            . json_encode($raceResponses, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)
        );
    }
    echo '[OK] concurrent final-slot requests produce one success and one capacity rejection' . PHP_EOL;

    $plannedCount = $pdo->prepare(
        'SELECT COUNT(*) FROM duty_assignments da
         JOIN duty_days dd ON dd.id = da.duty_day_id
         WHERE dd.school_id = 1 AND dd.duty_date = :date AND da.status = "planned"'
    );
    $plannedCount->execute(['date' => $dutyDate]);
    if ((int) $plannedCount->fetchColumn() !== 3) {
        throw new RuntimeException('Concurrent capacity test did not leave exactly three planned assignments.');
    }
    echo '[OK] duty capacity remains exactly three after concurrent requests' . PHP_EOL;
} catch (Throwable $exception) {
    $failure = $exception;
} finally {
    try {
        cleanup_concurrency_test(
            $pdo,
            $testUserIds,
            $testUsernames,
            $dutyDate,
            $dutyDayExisted,
            $loginAttemptBaseline,
        );
        echo '[OK] local concurrency-test data cleaned up' . PHP_EOL;
    } catch (Throwable $cleanupException) {
        $failure ??= $cleanupException;
    }
}

if ($failure !== null) {
    fwrite(STDERR, '[FAIL] ' . $failure->getMessage() . PHP_EOL);
    exit(1);
}

echo 'API concurrency smoke test passed.' . PHP_EOL;
