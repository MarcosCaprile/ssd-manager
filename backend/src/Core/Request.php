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

    public function query(string $key): ?string
    {
        if (!array_key_exists($key, $_GET) || is_array($_GET[$key])) {
            return null;
        }
        $value = trim((string) $_GET[$key]);
        return $value === '' ? null : $value;
    }

    /**
     * @return array{name:string,tmp_name:string,size:int,error:int}
     */
    public function uploadedFile(string $key): array
    {
        $file = $_FILES[$key] ?? null;
        if (!is_array($file) || is_array($file['error'] ?? null)) {
            Response::error('Es wurde keine Datei übermittelt.', 422);
        }
        $error = (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE);
        if ($error === UPLOAD_ERR_INI_SIZE || $error === UPLOAD_ERR_FORM_SIZE) {
            Response::error('Die Datei ist zu groß.', 413);
        }
        if ($error !== UPLOAD_ERR_OK) {
            Response::error('Die Datei konnte nicht hochgeladen werden.', 422);
        }
        $temporaryPath = (string) ($file['tmp_name'] ?? '');
        if ($temporaryPath === '' || !is_uploaded_file($temporaryPath)) {
            Response::error('Die hochgeladene Datei ist ungültig.', 422);
        }
        return [
            'name' => (string) ($file['name'] ?? 'Datei'),
            'tmp_name' => $temporaryPath,
            'size' => (int) ($file['size'] ?? 0),
            'error' => $error,
        ];
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
