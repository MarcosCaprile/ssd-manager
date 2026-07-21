<?php

declare(strict_types=1);

namespace App\Core;

final class Request
{
    public function method(): string
    {
        return strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
    }

    public function path(): string
    {
        $path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
        $base = trim(Config::env('API_BASE_PATH', '/api/v1') ?? '/api/v1', '/');
        $trimmed = trim($path, '/');
        if ($base !== '' && str_starts_with($trimmed, $base)) {
            $trimmed = trim(substr($trimmed, strlen($base)), '/');
        }
        return $trimmed;
    }

    /**
     * @return array<string,mixed>
     */
    public function json(): array
    {
        $raw = file_get_contents('php://input') ?: '';
        if ($raw === '') {
            return [];
        }
        $decoded = json_decode($raw, true);
        return is_array($decoded) ? $decoded : [];
    }

    public function bearerToken(): ?string
    {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
        if (preg_match('/Bearer\s+(.+)/i', $header, $matches)) {
            return trim($matches[1]);
        }
        return null;
    }

    public function ip(): string
    {
        return $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    }
}
