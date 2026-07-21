<?php

declare(strict_types=1);

namespace App\Core;

final class Config
{
    public static function env(string $key, ?string $default = null): ?string
    {
        $value = $_ENV[$key] ?? getenv($key);
        if ($value === false || $value === null || $value === '') {
            return $default;
        }
        return (string) $value;
    }

    public static function int(string $key, int $default): int
    {
        return (int) self::env($key, (string) $default);
    }

    public static function bool(string $key, bool $default = false): bool
    {
        $value = strtolower((string) self::env($key, $default ? 'true' : 'false'));
        return in_array($value, ['1', 'true', 'yes', 'on'], true);
    }
}
