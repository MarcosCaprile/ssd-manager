<?php

declare(strict_types=1);

$baseUrl = rtrim(getenv('SSD_API_TEST_BASE_URL') ?: 'http://127.0.0.1:8080/api/v1', '/');
$password = getenv('SSD_API_TEST_PASSWORD') ?: 'password';
$host = parse_url($baseUrl, PHP_URL_HOST);
if (!in_array($host, ['127.0.0.1', 'localhost', '::1'], true)) {
    fwrite(STDERR, '[FAIL] API smoke tests are restricted to a local backend.' . PHP_EOL);
    exit(1);
}

/**
 * @return array{status:int,body:array<string,mixed>}
 */
function request(string $method, string $path, ?array $payload = null, ?string $accessToken = null): array
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

function assert_status(array $response, int $expected, string $label): void
{
    if ($response['status'] !== $expected) {
        $message = $response['body']['message'] ?? 'unexpected response';
        throw new RuntimeException("{$label}: expected HTTP {$expected}, got {$response['status']} ({$message})");
    }
    echo "[OK] {$label}" . PHP_EOL;
}

/**
 * @return array{access_token:string,refresh_token:string}
 */
function login(string $identifier, string $password): array
{
    $response = request('POST', 'auth/login', [
        'identifier' => $identifier,
        'password' => $password,
        'device_name' => 'Backend API smoke test',
        'platform' => 'cli',
        'device_model' => 'local',
        'app_version' => '1.0.0+1',
    ]);
    assert_status($response, 200, "login with {$identifier}");

    $data = $response['body']['data'] ?? null;
    if (!is_array($data) || !is_string($data['access_token'] ?? null) || !is_string($data['refresh_token'] ?? null)) {
        throw new RuntimeException("login with {$identifier}: response contains no token pair");
    }

    return [
        'access_token' => $data['access_token'],
        'refresh_token' => $data['refresh_token'],
    ];
}

try {
    $health = request('GET', 'health');
    assert_status($health, 200, 'health check');
    if (($health['body']['data']['status'] ?? null) !== 'ok') {
        throw new RuntimeException('health check: response contains no ok status');
    }

    assert_status(request('GET', 'auth/session'), 401, 'unauthenticated session is rejected');

    $usernameSession = login('lehrer', $password);
    assert_status(request('GET', 'auth/session', accessToken: $usernameSession['access_token']), 200, 'authenticated session');
    assert_status(request('GET', 'me', accessToken: $usernameSession['access_token']), 200, 'own profile');
    assert_status(request('GET', 'duties/upcoming', accessToken: $usernameSession['access_token']), 200, 'upcoming duties');
    assert_status(request('GET', 'duties/history', accessToken: $usernameSession['access_token']), 200, 'duty history');
    assert_status(request('GET', 'announcements', accessToken: $usernameSession['access_token']), 200, 'announcements');
    assert_status(request('GET', 'users', accessToken: $usernameSession['access_token']), 200, 'user list');

    $refreshResponse = request('POST', 'auth/refresh', ['refresh_token' => $usernameSession['refresh_token']]);
    assert_status($refreshResponse, 200, 'token refresh');
    $refreshedAccessToken = $refreshResponse['body']['data']['access_token'] ?? null;
    if (!is_string($refreshedAccessToken)) {
        throw new RuntimeException('token refresh: response contains no access token');
    }
    assert_status(request('GET', 'auth/session', accessToken: $refreshedAccessToken), 200, 'refreshed session');
    assert_status(request('POST', 'auth/logout', accessToken: $refreshedAccessToken), 200, 'logout');
    assert_status(request('GET', 'auth/session', accessToken: $refreshedAccessToken), 401, 'logged-out session is rejected');

    $emailSession = login('lehrer@example.edu', $password);
    assert_status(request('POST', 'auth/logout', accessToken: $emailSession['access_token']), 200, 'email-login session logout');

    echo 'API smoke test passed.' . PHP_EOL;
} catch (Throwable $exception) {
    fwrite(STDERR, '[FAIL] ' . $exception->getMessage() . PHP_EOL);
    exit(1);
}
