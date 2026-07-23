<?php

declare(strict_types=1);

use App\Core\Config;
use App\Core\Database;

require dirname(__DIR__) . '/src/bootstrap.php';

$baseUrl = rtrim(getenv('SSD_API_TEST_BASE_URL') ?: 'http://127.0.0.1:8080/api/v1', '/');
$databaseHost = Config::env('DB_HOST', '127.0.0.1');
if (
    Config::env('APP_ENV') !== 'local'
    || !in_array(parse_url($baseUrl, PHP_URL_HOST), ['127.0.0.1', 'localhost', '::1'], true)
    || !in_array($databaseHost, ['127.0.0.1', 'localhost', '::1'], true)
) {
    fwrite(STDERR, '[FAIL] Attachment smoke tests require a local API and local APP_ENV/database.' . PHP_EOL);
    exit(1);
}

$pdo = Database::connection();
$seedPassword = getenv('SSD_API_TEST_PASSWORD') ?: 'password';
$loginAttemptBaseline = (int) $pdo->query('SELECT COALESCE(MAX(id), 0) FROM login_attempts')->fetchColumn();
$announcementId = null;
$attachmentIds = [];
$temporaryFiles = [];

/**
 * @return array{status:int,body:array<string,mixed>}
 */
function attachment_json_request(
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
 * @return array{status:int,body:string,content_type:string}
 */
function attachment_binary_request(string $path, ?string $accessToken): array
{
    global $baseUrl;

    $headers = ['Accept: */*'];
    if ($accessToken !== null) {
        $headers[] = 'Authorization: Bearer ' . $accessToken;
    }
    $handle = curl_init($baseUrl . '/' . ltrim($path, '/'));
    curl_setopt_array($handle, [
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 10,
    ]);
    $body = curl_exec($handle);
    if ($body === false) {
        throw new RuntimeException('Binary HTTP request failed: ' . curl_error($handle));
    }
    $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    $contentType = (string) curl_getinfo($handle, CURLINFO_CONTENT_TYPE);
    curl_close($handle);
    return ['status' => $status, 'body' => $body, 'content_type' => $contentType];
}

/**
 * @return array{status:int,body:array<string,mixed>}
 */
function attachment_upload(string $path, string $fileName, ?string $accessToken): array
{
    global $baseUrl;

    $headers = ['Accept: application/json'];
    if ($accessToken !== null) {
        $headers[] = 'Authorization: Bearer ' . $accessToken;
    }
    $handle = curl_init($baseUrl . '/announcements/attachments');
    curl_setopt_array($handle, [
        CURLOPT_POST => true,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_POSTFIELDS => [
            'attachment' => new CURLFile($path, 'application/octet-stream', $fileName),
        ],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 10,
    ]);
    $rawBody = curl_exec($handle);
    if ($rawBody === false) {
        throw new RuntimeException('Upload request failed: ' . curl_error($handle));
    }
    $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    curl_close($handle);
    $body = json_decode($rawBody, true, flags: JSON_THROW_ON_ERROR);
    if (!is_array($body)) {
        throw new RuntimeException('Expected a JSON upload response.');
    }
    return ['status' => $status, 'body' => $body];
}

function expect_attachment_status(array $response, int $expected, string $label): array
{
    if ($response['status'] !== $expected) {
        $message = $response['body']['message'] ?? 'unexpected response';
        throw new RuntimeException("{$label}: expected HTTP {$expected}, got {$response['status']} ({$message})");
    }
    echo "[OK] {$label}" . PHP_EOL;
    return $response;
}

function cleanup_attachments(
    PDO $pdo,
    ?int $announcementId,
    array $attachmentIds,
    int $loginAttemptBaseline,
): void {
    if ($announcementId !== null) {
        $pdo->prepare('DELETE FROM notification_logs WHERE announcement_id = :id')
            ->execute(['id' => $announcementId]);
        $pdo->prepare('DELETE FROM announcements WHERE id = :id')
            ->execute(['id' => $announcementId]);
    }
    if ($attachmentIds !== []) {
        $placeholders = implode(',', array_fill(0, count($attachmentIds), '?'));
        $pdo->prepare("DELETE FROM announcement_attachments WHERE id IN ({$placeholders})")
            ->execute($attachmentIds);
    }
    $pdo->prepare('DELETE FROM user_devices WHERE device_name = :device_name')
        ->execute(['device_name' => 'Attachment smoke test']);
    $pdo->prepare(
        'DELETE FROM login_attempts WHERE id > :baseline AND identifier = :identifier'
    )->execute(['baseline' => $loginAttemptBaseline, 'identifier' => 'noah']);
}

$failure = null;
try {
    $pngPath = tempnam(sys_get_temp_dir(), 'ssd-png-');
    $textPath = tempnam(sys_get_temp_dir(), 'ssd-txt-');
    $invalidPath = tempnam(sys_get_temp_dir(), 'ssd-invalid-');
    if ($pngPath === false || $textPath === false || $invalidPath === false) {
        throw new RuntimeException('Could not create attachment fixtures.');
    }
    $temporaryFiles = [$pngPath, $textPath, $invalidPath];
    file_put_contents(
        $pngPath,
        base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            true
        )
    );
    file_put_contents($textPath, 'SSD attachment smoke test');
    file_put_contents($invalidPath, '#!/bin/sh');

    $login = expect_attachment_status(attachment_json_request('POST', 'auth/login', [
        'identifier' => 'noah',
        'password' => $seedPassword,
        'device_name' => 'Attachment smoke test',
        'platform' => 'cli',
    ]), 200, 'first-aider login');
    $token = $login['body']['data']['access_token'] ?? null;
    if (!is_string($token)) {
        throw new RuntimeException('Login returned no access token.');
    }

    expect_attachment_status(
        attachment_upload($pngPath, 'foto.png', null),
        401,
        'unauthenticated upload is rejected'
    );
    expect_attachment_status(
        attachment_upload($invalidPath, 'script.sh', $token),
        422,
        'unsupported file type is rejected'
    );

    $pngUpload = expect_attachment_status(
        attachment_upload($pngPath, 'foto.png', $token),
        201,
        'PNG attachment upload'
    );
    $textUpload = expect_attachment_status(
        attachment_upload($textPath, 'hinweis.txt', $token),
        201,
        'text attachment upload'
    );
    $pngId = (int) ($pngUpload['body']['data']['id'] ?? 0);
    $textId = (int) ($textUpload['body']['data']['id'] ?? 0);
    if ($pngId < 1 || $textId < 1) {
        throw new RuntimeException('Upload response contains no attachment IDs.');
    }
    $attachmentIds = [$pngId, $textId];

    $announcement = expect_attachment_status(attachment_json_request('POST', 'announcements', [
        'message' => '',
        'attachment_ids' => $attachmentIds,
    ], $token), 201, 'attachment-only announcement');
    $announcementId = (int) ($announcement['body']['data']['id'] ?? 0);
    $responseAttachments = $announcement['body']['data']['attachments'] ?? null;
    if (
        $announcementId < 1
        || !is_array($responseAttachments)
        || count($responseAttachments) !== 2
        || ($responseAttachments[0]['is_image'] ?? false) !== true
    ) {
        throw new RuntimeException('Announcement response contains incomplete attachment metadata.');
    }

    $storage = expect_attachment_status(
        attachment_json_request('GET', 'me/attachments?sort=size_desc', accessToken: $token),
        200,
        'personal attachment storage list'
    );
    $storageData = $storage['body']['data'] ?? null;
    if (
        !is_array($storageData)
        || (int) ($storageData['limit_bytes'] ?? 0) !== 100 * 1024 * 1024
        || count($storageData['attachments'] ?? []) !== 2
        || (int) ($storageData['used_bytes'] ?? 0) <= 0
    ) {
        throw new RuntimeException('Personal storage response is incomplete.');
    }
    echo '[OK] personal storage exposes 100 MB quota and own files' . PHP_EOL;

    expect_attachment_status(
        attachment_json_request('DELETE', "me/attachments/{$textId}", accessToken: $token),
        200,
        'owner deletes attachment from cloud storage'
    );
    $storageAfterDelete = expect_attachment_status(
        attachment_json_request('GET', 'me/attachments', accessToken: $token),
        200,
        'personal storage list after delete'
    );
    if (count($storageAfterDelete['body']['data']['attachments'] ?? []) !== 1) {
        throw new RuntimeException('Deleted attachment still appears in personal storage.');
    }
    echo '[OK] deleted attachment no longer consumes personal storage' . PHP_EOL;

    expect_attachment_status(attachment_json_request('POST', 'announcements', [
        'message' => 'Wiederverwendung',
        'attachment_ids' => [$pngId],
    ], $token), 422, 'claimed attachment cannot be reused');

    $list = expect_attachment_status(
        attachment_json_request('GET', 'announcements', accessToken: $token),
        200,
        'announcement list with attachments'
    );
    $found = null;
    foreach (($list['body']['data'] ?? []) as $item) {
        if ((int) ($item['id'] ?? 0) === $announcementId) {
            $found = $item;
            break;
        }
    }
    if (!is_array($found) || count($found['attachments'] ?? []) !== 2) {
        throw new RuntimeException('Announcement list omitted attachment metadata or its deletion marker.');
    }
    $deletedAttachment = null;
    foreach ($found['attachments'] as $attachment) {
        if ((int) ($attachment['id'] ?? 0) === $textId) {
            $deletedAttachment = $attachment;
        }
    }
    if (!is_array($deletedAttachment) || ($deletedAttachment['is_deleted'] ?? false) !== true) {
        throw new RuntimeException('Deleted cloud attachment is not retained as an announcement marker.');
    }
    echo '[OK] announcement keeps a marker for deleted cloud content' . PHP_EOL;

    $deletedDownload = attachment_binary_request(
        "announcements/attachments/{$textId}",
        $token
    );
    if ($deletedDownload['status'] !== 404) {
        throw new RuntimeException('Deleted attachment content is still downloadable.');
    }
    echo '[OK] deleted attachment content is no longer downloadable' . PHP_EOL;

    $download = attachment_binary_request("announcements/attachments/{$pngId}", $token);
    if (
        $download['status'] !== 200
        || $download['content_type'] !== 'image/png'
        || $download['body'] !== file_get_contents($pngPath)
    ) {
        throw new RuntimeException('Authenticated image download did not preserve content and MIME type.');
    }
    echo '[OK] authenticated image download preserves content' . PHP_EOL;
    $unauthenticatedDownload = attachment_binary_request(
        "announcements/attachments/{$pngId}",
        null
    );
    if ($unauthenticatedDownload['status'] !== 401) {
        throw new RuntimeException('Unauthenticated attachment download was not rejected.');
    }
    echo '[OK] unauthenticated attachment download is rejected' . PHP_EOL;

    expect_attachment_status(
        attachment_json_request('POST', 'auth/logout', accessToken: $token),
        200,
        'first-aider logout'
    );
} catch (Throwable $exception) {
    $failure = $exception;
} finally {
    try {
        cleanup_attachments($pdo, $announcementId, $attachmentIds, $loginAttemptBaseline);
        foreach ($temporaryFiles as $file) {
            if (is_string($file) && is_file($file)) {
                unlink($file);
            }
        }
        echo '[OK] local attachment test data cleaned up' . PHP_EOL;
    } catch (Throwable $cleanupException) {
        $failure ??= $cleanupException;
    }
}

if ($failure !== null) {
    fwrite(STDERR, '[FAIL] ' . $failure->getMessage() . PHP_EOL);
    exit(1);
}

echo 'Attachment API smoke test passed.' . PHP_EOL;
