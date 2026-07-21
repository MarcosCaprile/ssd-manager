<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Config;

final class TokenService
{
    /**
     * @param array<string,mixed> $payload
     */
    public function issue(array $payload, int $ttlSeconds): string
    {
        $header = ['alg' => 'HS256', 'typ' => 'JWT'];
        $now = time();
        $payload['iat'] = $now;
        $payload['exp'] = $now + $ttlSeconds;
        $segments = [
            $this->base64Url(json_encode($header, JSON_THROW_ON_ERROR)),
            $this->base64Url(json_encode($payload, JSON_THROW_ON_ERROR)),
        ];
        $signature = hash_hmac('sha256', implode('.', $segments), $this->secret(), true);
        $segments[] = $this->base64Url($signature);
        return implode('.', $segments);
    }

    /**
     * @return array<string,mixed>|null
     */
    public function verify(string $token): ?array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return null;
        }
        [$header, $payload, $signature] = $parts;
        $expected = $this->base64Url(hash_hmac('sha256', $header . '.' . $payload, $this->secret(), true));
        if (!hash_equals($expected, $signature)) {
            return null;
        }
        $decoded = json_decode($this->base64UrlDecode($payload), true);
        if (!is_array($decoded) || (int) ($decoded['exp'] ?? 0) < time()) {
            return null;
        }
        return $decoded;
    }

    private function secret(): string
    {
        $secret = Config::env('JWT_SECRET', '');
        if ($secret === '') {
            throw new \RuntimeException('JWT_SECRET is required.');
        }
        return $secret;
    }

    private function base64Url(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    private function base64UrlDecode(string $value): string
    {
        return base64_decode(strtr($value, '-_', '+/')) ?: '';
    }
}
