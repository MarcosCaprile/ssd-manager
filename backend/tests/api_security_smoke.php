<?php

declare(strict_types=1);

use App\Core\Config;
use App\Core\Database;
use App\Services\PasswordHasher;

require dirname(__DIR__) . '/src/bootstrap.php';

$baseUrl = rtrim(getenv('SSD_API_TEST_BASE_URL') ?: 'http://127.0.0.1:8080/api/v1', '/');
$databaseHost = Config::env('DB_HOST', '127.0.0.1');
if (
    Config::env('APP_ENV') !== 'local'
    || !in_array(parse_url($baseUrl, PHP_URL_HOST), ['127.0.0.1', 'localhost', '::1'], true)
    || !in_array($databaseHost, ['127.0.0.1', 'localhost', '::1'], true)
) {
    fwrite(STDERR, '[FAIL] Security smoke tests require a local API and local APP_ENV/database.' . PHP_EOL);
    exit(1);
}

$pdo = Database::connection();
$suffix = bin2hex(random_bytes(5));
$schoolId = null;
$crossSchoolUserId = null;
$crossSchoolDutyDayId = null;
$crossSchoolAssignmentId = null;
$crossSchoolAnnouncementId = null;
$loginAttemptBaseline = (int) $pdo->query('SELECT COALESCE(MAX(id), 0) FROM login_attempts')->fetchColumn();

/**
 * @return array{status:int,body:array<string,mixed>}
 */
function security_request(
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

/**
 * @return array{status:int,body:string}
 */
function security_binary_request(string $path, string $accessToken): array
{
    global $baseUrl;

    $handle = curl_init($baseUrl . '/' . ltrim($path, '/'));
    curl_setopt_array($handle, [
        CURLOPT_HTTPHEADER => [
            'Accept: */*',
            'Authorization: Bearer ' . $accessToken,
        ],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 10,
    ]);
    $body = curl_exec($handle);
    if ($body === false) {
        throw new RuntimeException('Binary HTTP request failed: ' . curl_error($handle));
    }
    $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    curl_close($handle);
    return ['status' => $status, 'body' => $body];
}

function expect_security_status(array $response, int $expected, string $label): array
{
    if ($response['status'] !== $expected) {
        $message = $response['body']['message'] ?? 'unexpected response';
        throw new RuntimeException("{$label}: expected HTTP {$expected}, got {$response['status']} ({$message})");
    }
    echo "[OK] {$label}" . PHP_EOL;
    return $response;
}

function contains_id(array $response, int $id): bool
{
    $items = $response['body']['data'] ?? null;
    if (!is_array($items)) {
        throw new RuntimeException('Expected a list response.');
    }
    foreach ($items as $item) {
        if ((int) ($item['id'] ?? 0) === $id || (int) ($item['user_id'] ?? 0) === $id) {
            return true;
        }
        foreach (($item['assignments'] ?? []) as $assignment) {
            if ((int) ($assignment['user_id'] ?? 0) === $id) {
                return true;
            }
        }
    }
    return false;
}

function cleanup_security_test(
    PDO $pdo,
    ?int $schoolId,
    ?int $crossSchoolUserId,
    ?int $crossSchoolDutyDayId,
    ?int $crossSchoolAnnouncementId,
    int $loginAttemptBaseline,
    string $crossSchoolUsername,
): void {
    $pdo->prepare('DELETE FROM user_devices WHERE device_name = :device_name')
        ->execute(['device_name' => 'Backend API security smoke test']);
    $pdo->prepare('DELETE FROM login_attempts WHERE id > :baseline AND identifier IN (:teacher, :cross_user)')
        ->execute([
            'baseline' => $loginAttemptBaseline,
            'teacher' => 'lehrer',
            'cross_user' => $crossSchoolUsername,
        ]);
    if ($crossSchoolAnnouncementId !== null) {
        $pdo->prepare('DELETE FROM notification_logs WHERE announcement_id = :id')
            ->execute(['id' => $crossSchoolAnnouncementId]);
        $pdo->prepare('DELETE FROM announcements WHERE id = :id')->execute(['id' => $crossSchoolAnnouncementId]);
    }
    if ($crossSchoolDutyDayId !== null) {
        $pdo->prepare('DELETE FROM duty_assignments WHERE duty_day_id = :id')->execute(['id' => $crossSchoolDutyDayId]);
        $pdo->prepare('DELETE FROM duty_days WHERE id = :id')->execute(['id' => $crossSchoolDutyDayId]);
    }
    if ($crossSchoolUserId !== null) {
        $pdo->prepare('DELETE FROM audit_logs WHERE actor_user_id = :actor_id OR target_user_id = :target_id')
            ->execute(['actor_id' => $crossSchoolUserId, 'target_id' => $crossSchoolUserId]);
        $pdo->prepare('DELETE FROM users WHERE id = :id')->execute(['id' => $crossSchoolUserId]);
    }
    if ($schoolId !== null) {
        $pdo->prepare('DELETE FROM schools WHERE id = :id')->execute(['id' => $schoolId]);
    }
}

$crossSchoolUsername = 'cross_school_' . $suffix;
$failure = null;
try {
    $pdo->prepare('INSERT INTO schools (name, slug, active) VALUES (:name, :slug, 1)')->execute([
        'name' => 'API Cross-School Test',
        'slug' => 'api-cross-school-' . $suffix,
    ]);
    $schoolId = (int) $pdo->lastInsertId();
    $pdo->prepare(
        'INSERT INTO users
         (school_id, first_name, last_name, username, email, password_hash, role, status, must_change_password)
         VALUES (:school_id, "Cross", "School", :username, :email, :password_hash, "sanitaeter", "active", 1)'
    )->execute([
        'school_id' => $schoolId,
        'username' => $crossSchoolUsername,
        'email' => $crossSchoolUsername . '@example.test',
        'password_hash' => PasswordHasher::hash('CrossSchoolPassword!2026'),
    ]);
    $crossSchoolUserId = (int) $pdo->lastInsertId();
    $testDate = (new DateTimeImmutable('today', new DateTimeZone('Europe/Berlin')))->modify('+3 days')->format('Y-m-d');
    $pdo->prepare('INSERT INTO duty_days (school_id, duty_date, capacity, is_active) VALUES (:school_id, :date, 3, 1)')
        ->execute(['school_id' => $schoolId, 'date' => $testDate]);
    $crossSchoolDutyDayId = (int) $pdo->lastInsertId();
    $pdo->prepare(
        'INSERT INTO duty_assignments
         (duty_day_id, user_id, status, assigned_by_user_id, assignment_type)
         VALUES (:day_id, :user_id, "planned", NULL, "self")'
    )->execute(['day_id' => $crossSchoolDutyDayId, 'user_id' => $crossSchoolUserId]);
    $crossSchoolAssignmentId = (int) $pdo->lastInsertId();
    $pdo->prepare(
        'INSERT INTO announcements (school_id, sender_user_id, message)
         VALUES (:school_id, :user_id, :message)'
    )->execute([
        'school_id' => $schoolId,
        'user_id' => $crossSchoolUserId,
        'message' => 'Cross-school announcement ' . $suffix,
    ]);
    $crossSchoolAnnouncementId = (int) $pdo->lastInsertId();
    $pdo->prepare(
        'INSERT INTO announcement_attachments
         (school_id, uploaded_by_user_id, announcement_id, file_name, mime_type, size_bytes, content)
         VALUES (:school_id, :user_id, :announcement_id, "other-school.txt", "text/plain", 12, :content)'
    )->execute([
        'school_id' => $schoolId,
        'user_id' => $crossSchoolUserId,
        'announcement_id' => $crossSchoolAnnouncementId,
        'content' => 'private data',
    ]);
    $crossSchoolAttachmentId = (int) $pdo->lastInsertId();

    $login = expect_security_status(security_request('POST', 'auth/login', [
        'identifier' => 'lehrer',
        'password' => getenv('SSD_API_TEST_PASSWORD') ?: 'password',
        'device_name' => 'Backend API security smoke test',
        'platform' => 'cli',
    ]), 200, 'teacher login');
    $teacherToken = $login['body']['data']['access_token'] ?? null;
    if (!is_string($teacherToken)) {
        throw new RuntimeException('Teacher login response contains no access token.');
    }

    $users = expect_security_status(
        security_request('GET', 'users', accessToken: $teacherToken),
        200,
        'school-scoped user list'
    );
    if (contains_id($users, $crossSchoolUserId)) {
        throw new RuntimeException('User list leaked a user from another school.');
    }
    echo '[OK] user list does not leak another school' . PHP_EOL;

    $announcements = expect_security_status(
        security_request('GET', 'announcements', accessToken: $teacherToken),
        200,
        'school-scoped announcement list'
    );
    if (contains_id($announcements, $crossSchoolAnnouncementId)) {
        throw new RuntimeException('Announcement list leaked another school.');
    }
    echo '[OK] announcement list does not leak another school' . PHP_EOL;

    $crossSchoolDownload = security_binary_request(
        "announcements/attachments/{$crossSchoolAttachmentId}",
        $teacherToken
    );
    if ($crossSchoolDownload['status'] !== 404) {
        throw new RuntimeException('Attachment download leaked another school.');
    }
    echo '[OK] announcement attachment from another school is inaccessible' . PHP_EOL;

    $duties = expect_security_status(
        security_request('GET', "duties/{$testDate}", accessToken: $teacherToken),
        200,
        'school-scoped duty details'
    );
    if (contains_id(['body' => ['data' => [$duties['body']['data']]]], $crossSchoolUserId)) {
        throw new RuntimeException('Duty details leaked an assignment from another school.');
    }
    echo '[OK] duty details do not leak another school' . PHP_EOL;

    expect_security_status(
        security_request('GET', "users/{$crossSchoolUserId}", accessToken: $teacherToken),
        404,
        'other-school profile is inaccessible'
    );
    expect_security_status(
        security_request(
            'PATCH',
            "users/{$crossSchoolUserId}/role",
            ['role' => 'sani_leitung'],
            $teacherToken
        ),
        404,
        'other-school role cannot be changed'
    );
    expect_security_status(
        security_request('POST', "users/{$crossSchoolUserId}/deactivate", accessToken: $teacherToken),
        404,
        'other-school account cannot be deactivated'
    );
    expect_security_status(
        security_request('POST', "duties/{$testDate}/assignments", ['user_id' => $crossSchoolUserId], $teacherToken),
        422,
        'other-school user cannot be assigned to duty'
    );
    expect_security_status(
        security_request(
            'DELETE',
            "duties/{$testDate}/assignments/{$crossSchoolAssignmentId}",
            accessToken: $teacherToken
        ),
        404,
        'other-school duty assignment cannot be removed'
    );
    expect_security_status(security_request('POST', 'auth/login', [
        'identifier' => $crossSchoolUsername,
        'password' => 'CrossSchoolPassword!2026',
        'device_name' => 'Backend API security smoke test',
        'platform' => 'cli',
    ]), 401, 'default-school login cannot authenticate another school');

    expect_security_status(
        security_request('GET', 'duties/not-a-date', accessToken: $teacherToken),
        422,
        'malformed duty date is rejected'
    );
    expect_security_status(
        security_request('GET', 'duties/2026-99-99', accessToken: $teacherToken),
        422,
        'invalid calendar date is rejected'
    );
    expect_security_status(
        security_request('POST', 'announcements', ['message' => '   '], $teacherToken),
        422,
        'empty announcement is rejected'
    );
    expect_security_status(
        security_request('POST', 'announcements', ['message' => str_repeat('a', 2001)], $teacherToken),
        422,
        'oversized announcement is rejected'
    );
    expect_security_status(
        security_request('POST', 'users', ['first_name' => 'Incomplete'], $teacherToken),
        422,
        'incomplete account payload is rejected'
    );
    expect_security_status(security_request('POST', 'users', [
        'first_name' => 'Short',
        'last_name' => 'Password',
        'username' => 'short_' . $suffix,
        'email' => 'short_' . $suffix . '@example.test',
        'temporary_password' => '123456789',
        'role' => 'sanitaeter',
        'sanitaeter_since' => '2024-01-01',
    ], $teacherToken), 422, 'short temporary password is rejected');
    expect_security_status(security_request('POST', 'users', [
        'first_name' => 'Invalid',
        'last_name' => 'Role',
        'username' => 'invalid_role_' . $suffix,
        'email' => 'invalid_role_' . $suffix . '@example.test',
        'temporary_password' => 'ValidPassword!2026',
        'role' => 'administrator',
    ], $teacherToken), 422, 'invalid role is rejected');
    expect_security_status(security_request('POST', 'users', [
        'first_name' => 'Duplicate',
        'last_name' => 'Username',
        'username' => 'lehrer',
        'email' => 'unique_' . $suffix . '@example.test',
        'temporary_password' => 'ValidPassword!2026',
        'role' => 'sanitaeter',
        'sanitaeter_since' => '2024-01-01',
    ], $teacherToken), 409, 'duplicate username is reported as conflict');
    expect_security_status(security_request('POST', 'users', [
        'first_name' => 'Duplicate',
        'last_name' => 'Email',
        'username' => 'unique_' . $suffix,
        'email' => 'lehrer@example.edu',
        'temporary_password' => 'ValidPassword!2026',
        'role' => 'sanitaeter',
        'sanitaeter_since' => '2024-01-01',
    ], $teacherToken), 409, 'duplicate email is reported as conflict');
    expect_security_status(
        security_request('POST', "duties/{$testDate}/assignments", ['user_id' => 0], $teacherToken),
        422,
        'missing duty target is rejected'
    );
    expect_security_status(
        security_request('PATCH', 'users/1', ['first_name' => 'Disabled'], $teacherToken),
        405,
        'disabled profile editing remains unavailable'
    );
    expect_security_status(
        security_request('GET', 'does-not-exist', accessToken: $teacherToken),
        404,
        'unknown endpoint is rejected'
    );
    expect_security_status(
        security_request('POST', 'auth/logout', accessToken: $teacherToken),
        200,
        'teacher logout'
    );
} catch (Throwable $exception) {
    $failure = $exception;
} finally {
    try {
        cleanup_security_test(
            $pdo,
            $schoolId,
            $crossSchoolUserId,
            $crossSchoolDutyDayId,
            $crossSchoolAnnouncementId,
            $loginAttemptBaseline,
            $crossSchoolUsername,
        );
        echo '[OK] local security-test data cleaned up' . PHP_EOL;
    } catch (Throwable $cleanupException) {
        $failure ??= $cleanupException;
    }
}

if ($failure !== null) {
    fwrite(STDERR, '[FAIL] ' . $failure->getMessage() . PHP_EOL);
    exit(1);
}

echo 'API security smoke test passed.' . PHP_EOL;
