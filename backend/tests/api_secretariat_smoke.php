<?php

declare(strict_types=1);

use App\Core\Config;
use App\Core\Database;
use App\Services\DutyRules;

require dirname(__DIR__) . '/src/bootstrap.php';

$baseUrl = rtrim(getenv('SSD_API_TEST_BASE_URL') ?: 'http://127.0.0.1:8080/api/v1', '/');
$seedPassword = getenv('SSD_API_TEST_PASSWORD') ?: 'password';
$databaseHost = Config::env('DB_HOST', '127.0.0.1');
if (
    Config::env('APP_ENV') !== 'local'
    || !in_array(parse_url($baseUrl, PHP_URL_HOST), ['127.0.0.1', 'localhost', '::1'], true)
    || !in_array($databaseHost, ['127.0.0.1', 'localhost', '::1'], true)
) {
    fwrite(STDERR, '[FAIL] Secretariat smoke tests require a local API and local APP_ENV/database.' . PHP_EOL);
    exit(1);
}

$pdo = Database::connection();
$suffix = bin2hex(random_bytes(5));
$username = 'secretariat_' . $suffix;
$password = 'SecretariatSmoke!2026';
$userId = null;
$announcementId = null;
$loginAttemptBaseline = (int) $pdo->query('SELECT COALESCE(MAX(id), 0) FROM login_attempts')->fetchColumn();

/**
 * @return array{status:int,body:array<string,mixed>}
 */
function secretariat_request(
    string $method,
    string $path,
    ?array $payload = null,
    ?string $accessToken = null,
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
    $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    curl_close($handle);
    $body = json_decode($rawBody, true, flags: JSON_THROW_ON_ERROR);
    if (!is_array($body)) {
        throw new RuntimeException('Expected a JSON object from ' . $path);
    }
    return ['status' => $status, 'body' => $body];
}

function expect_secretariat_status(array $response, int $expected, string $label): array
{
    if ($response['status'] !== $expected) {
        $message = $response['body']['message'] ?? 'unexpected response';
        throw new RuntimeException("{$label}: expected HTTP {$expected}, got {$response['status']} ({$message})");
    }
    echo "[OK] {$label}" . PHP_EOL;
    return $response;
}

function secretariat_login(string $identifier, string $password): string
{
    $response = expect_secretariat_status(secretariat_request('POST', 'auth/login', [
        'identifier' => $identifier,
        'password' => $password,
        'device_name' => 'Secretariat smoke test',
        'platform' => 'cli',
    ]), 200, "{$identifier} login");
    $token = $response['body']['data']['access_token'] ?? null;
    if (!is_string($token)) {
        throw new RuntimeException('Login returned no access token.');
    }
    return $token;
}

$failure = null;
try {
    $teacher = secretariat_login('lehrer', $seedPassword);
    expect_secretariat_status(secretariat_request('POST', 'users', [
        'first_name' => 'Test',
        'last_name' => 'Sekretariat',
        'username' => $username,
        'email' => $username . '@example.test',
        'temporary_password' => $password,
        'role' => 'sekretariat',
    ], $teacher), 201, 'teacher creates secretariat account');

    $find = $pdo->prepare('SELECT id, sanitaeter_since FROM users WHERE school_id = 1 AND username = :username');
    $find->execute(['username' => $username]);
    $row = $find->fetch();
    $userId = (int) ($row['id'] ?? 0);
    if ($userId < 1 || ($row['sanitaeter_since'] ?? null) !== null) {
        throw new RuntimeException('Secretariat account was not stored correctly.');
    }

    $secretariat = secretariat_login($username, $password);
    expect_secretariat_status(
        secretariat_request('GET', 'duties/upcoming', accessToken: $secretariat),
        200,
        'secretariat views duty plan'
    );
    $users = expect_secretariat_status(
        secretariat_request('GET', 'users', accessToken: $secretariat),
        200,
        'secretariat views school user list'
    );
    $roles = array_unique(array_column($users['body']['data'] ?? [], 'role'));
    if (!in_array('sanitaeter', $roles, true) || !in_array('teacher', $roles, true)) {
        throw new RuntimeException('Secretariat user list omits sanitary or school staff sections.');
    }
    expect_secretariat_status(
        secretariat_request('GET', 'announcements', accessToken: $secretariat),
        200,
        'secretariat views announcements'
    );
    $announcement = expect_secretariat_status(
        secretariat_request(
            'POST',
            'announcements',
            ['message' => 'Nachricht aus dem Sekretariat ' . $suffix],
            $secretariat
        ),
        201,
        'secretariat sends announcement'
    );
    $announcementId = (int) ($announcement['body']['data']['id'] ?? 0);

    $rules = new DutyRules(Config::env('SCHOOL_TIMEZONE', 'Europe/Berlin') ?? 'Europe/Berlin');
    $now = new DateTimeImmutable('now', new DateTimeZone('Europe/Berlin'));
    $bookableDate = null;
    for ($offset = 0; $offset < 14; $offset++) {
        $candidate = $now->modify("+{$offset} days")->format('Y-m-d');
        if ($rules->canBook($candidate, $now)) {
            $bookableDate = $candidate;
            break;
        }
    }
    if ($bookableDate === null) {
        throw new RuntimeException('No bookable weekday found.');
    }

    expect_secretariat_status(
        secretariat_request('POST', "duties/{$bookableDate}/self", accessToken: $secretariat),
        403,
        'secretariat cannot self-assign'
    );
    expect_secretariat_status(
        secretariat_request(
            'POST',
            "duties/{$bookableDate}/assignments",
            ['user_id' => 3],
            $secretariat
        ),
        403,
        'secretariat cannot assign others'
    );
    expect_secretariat_status(
        secretariat_request('POST', 'users', [
            'first_name' => 'Nicht',
            'last_name' => 'Erlaubt',
            'username' => 'forbidden_' . $suffix,
            'email' => 'forbidden_' . $suffix . '@example.test',
            'temporary_password' => $password,
            'role' => 'sekretariat',
        ], $secretariat),
        403,
        'secretariat cannot create accounts'
    );
    expect_secretariat_status(
        secretariat_request(
            'PATCH',
            "users/{$userId}/role",
            ['role' => 'sanitaeter'],
            $teacher
        ),
        403,
        'teacher cannot convert secretariat account into sanitary role'
    );
    $profile = expect_secretariat_status(
        secretariat_request('GET', "users/{$userId}", accessToken: $teacher),
        200,
        'teacher views secretariat profile'
    );
    $profileData = $profile['body']['data'] ?? [];
    if (
        !is_array($profileData)
        || !array_key_exists('statistics', $profileData)
        || $profileData['statistics'] !== null
    ) {
        throw new RuntimeException('Secretariat profile unexpectedly contains duty statistics.');
    }
} catch (Throwable $exception) {
    $failure = $exception;
} finally {
    try {
        if ($announcementId !== null) {
            $pdo->prepare('DELETE FROM notification_logs WHERE announcement_id = :id')
                ->execute(['id' => $announcementId]);
            $pdo->prepare('DELETE FROM announcements WHERE id = :id')
                ->execute(['id' => $announcementId]);
        }
        if ($userId !== null) {
            $pdo->prepare('DELETE FROM user_devices WHERE user_id = :id')->execute(['id' => $userId]);
            $pdo->prepare(
                'DELETE FROM audit_logs WHERE actor_user_id = :actor_id OR target_user_id = :target_id'
            )->execute(['actor_id' => $userId, 'target_id' => $userId]);
            $pdo->prepare('DELETE FROM users WHERE id = :id')->execute(['id' => $userId]);
        }
        $pdo->prepare('DELETE FROM user_devices WHERE device_name = :device_name')
            ->execute(['device_name' => 'Secretariat smoke test']);
        $pdo->prepare(
            'DELETE FROM login_attempts
             WHERE id > :baseline AND identifier IN (:teacher, :secretariat)'
        )->execute([
            'baseline' => $loginAttemptBaseline,
            'teacher' => 'lehrer',
            'secretariat' => $username,
        ]);
        echo '[OK] local secretariat test data cleaned up' . PHP_EOL;
    } catch (Throwable $cleanupException) {
        $failure ??= $cleanupException;
    }
}

if ($failure !== null) {
    fwrite(STDERR, '[FAIL] ' . $failure->getMessage() . PHP_EOL);
    exit(1);
}

echo 'Secretariat API smoke test passed.' . PHP_EOL;
