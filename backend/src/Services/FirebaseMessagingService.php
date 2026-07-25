<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Config;

final class FirebaseMessagingService
{
    private ?string $accessToken = null;
    private int $expiresAt = 0;

    /**
     * @param array<string,string> $data
     */
    public function sendToToken(string $token, string $title, string $body, array $data = []): string
    {
        if (!Config::bool('FCM_ENABLED', false)) {
            return 'skipped';
        }

        $projectId = Config::env('FIREBASE_PROJECT_ID') ?: $this->serviceAccount()['project_id'] ?? null;
        if (!$projectId) {
            return 'missing_project';
        }

        $data = array_map(static fn (mixed $value): string => (string) $value, $data);
        $data['title'] = $title;
        $data['body'] = $body;
        $isAnnouncement = ($data['route'] ?? '') === 'announcements';
        $isSickReport = ($data['system_type'] ?? '') === 'duty_sick_reported'
            || ($data['notification_type'] ?? '') === 'announcement_system_sick';
        $isHighPriority = ($data['priority'] ?? '') === 'high' || $isAnnouncement;

        $payload = $this->messagePayload(
            $token,
            $title,
            $body,
            $data,
            $isHighPriority,
            $isAnnouncement,
            $isSickReport
        );

        $response = $this->postJson(
            "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send",
            $payload,
            ['Authorization: Bearer ' . $this->accessToken()]
        );

        return $response['ok'] ? 'sent' : 'failed';
    }

    /**
     * @param array<string,string> $data
     * @return array<string,mixed>
     */
    private function messagePayload(
        string $token,
        string $title,
        string $body,
        array $data,
        bool $isHighPriority,
        bool $isAnnouncement,
        bool $isSickReport,
    ): array {
        $data = $this->withoutReservedDataKeys($data);
        return [
            'message' => [
                'token' => $token,
                'data' => $data,
                'android' => [
                    'priority' => $isHighPriority ? 'HIGH' : 'NORMAL',
                ],
                'apns' => [
                    'headers' => [
                        'apns-priority' => '10',
                    ],
                    'payload' => [
                        'aps' => [
                            'alert' => [
                                'title' => $title,
                                'body' => $body,
                            ],
                            'sound' => 'default',
                            'thread-id' => $isSickReport
                                ? 'ssd-sick-reports'
                                : ($isAnnouncement ? 'ssd-announcements' : 'ssd-manager'),
                        ],
                    ],
                ],
            ],
        ];
    }

    /**
     * FCM rejects the complete message when custom data contains a reserved
     * key. Keep this boundary defensive even if a future caller adds one.
     *
     * @param array<string,string> $data
     * @return array<string,string>
     */
    private function withoutReservedDataKeys(array $data): array
    {
        return array_filter(
            $data,
            static function (string $key): bool {
                $normalized = strtolower($key);
                return $normalized !== 'from'
                    && $normalized !== 'message_type'
                    && !str_starts_with($normalized, 'google.')
                    && !str_starts_with($normalized, 'gcm.');
            },
            ARRAY_FILTER_USE_KEY
        );
    }

    private function accessToken(): string
    {
        if ($this->accessToken !== null && $this->expiresAt > time() + 60) {
            return $this->accessToken;
        }

        $account = $this->serviceAccount();
        $now = time();
        $header = $this->base64Url(json_encode(['alg' => 'RS256', 'typ' => 'JWT'], JSON_THROW_ON_ERROR));
        $claim = $this->base64Url(json_encode([
            'iss' => $account['client_email'],
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token',
            'iat' => $now,
            'exp' => $now + 3600,
        ], JSON_THROW_ON_ERROR));
        openssl_sign($header . '.' . $claim, $signature, $account['private_key'], OPENSSL_ALGO_SHA256);
        $assertion = $header . '.' . $claim . '.' . $this->base64Url($signature);

        $ch = curl_init('https://oauth2.googleapis.com/token');
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => http_build_query([
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $assertion,
            ]),
        ]);
        $raw = curl_exec($ch);
        curl_close($ch);
        $decoded = json_decode((string) $raw, true);
        if (!is_array($decoded) || empty($decoded['access_token'])) {
            throw new \RuntimeException('Could not fetch Firebase access token.');
        }
        $this->accessToken = (string) $decoded['access_token'];
        $this->expiresAt = $now + (int) ($decoded['expires_in'] ?? 3600);
        return $this->accessToken;
    }

    /**
     * @return array<string,mixed>
     */
    private function serviceAccount(): array
    {
        $encoded = Config::env('FIREBASE_SERVICE_ACCOUNT_JSON_BASE64');
        if ($encoded !== null) {
            $compact = preg_replace('/\s+/', '', $encoded);
            $contents = $compact === null ? false : base64_decode($compact, true);
            if ($contents === false) {
                throw new \RuntimeException('Invalid base64 Firebase service account configuration.');
            }
        } else {
            $path = Config::env('FIREBASE_SERVICE_ACCOUNT');
            if (!$path || !is_file($path)) {
                throw new \RuntimeException('Firebase service account is not configured.');
            }
            $contents = file_get_contents($path);
        }

        $decoded = json_decode($contents ?: '', true);
        if (
            !is_array($decoded)
            || ($decoded['type'] ?? null) !== 'service_account'
            || !is_string($decoded['project_id'] ?? null)
            || trim($decoded['project_id']) === ''
            || !is_string($decoded['client_email'] ?? null)
            || trim($decoded['client_email']) === ''
            || !is_string($decoded['private_key'] ?? null)
            || !str_contains($decoded['private_key'], 'BEGIN PRIVATE KEY')
        ) {
            throw new \RuntimeException('Invalid Firebase service account JSON.');
        }
        return $decoded;
    }

    /**
     * @param array<string,mixed> $payload
     * @param array<int,string> $headers
     * @return array{ok:bool,body:string}
     */
    private function postJson(string $url, array $payload, array $headers = []): array
    {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_HTTPHEADER => array_merge(['Content-Type: application/json'], $headers),
            CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
        ]);
        $body = (string) curl_exec($ch);
        $code = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        curl_close($ch);
        return ['ok' => $code >= 200 && $code < 300, 'body' => $body];
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
