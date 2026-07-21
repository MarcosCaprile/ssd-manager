<?php

declare(strict_types=1);

namespace App\Core;

final class Validation
{
    /**
     * @param array<string,mixed> $data
     */
    public static function string(array $data, string $key, int $min = 1, int $max = 255): string
    {
        $value = trim((string) ($data[$key] ?? ''));
        if (mb_strlen($value) < $min || mb_strlen($value) > $max) {
            Response::error('Ungültige Eingabe: ' . $key, 422);
        }
        return $value;
    }

    /**
     * @param array<string,mixed> $data
     */
    public static function optionalString(array $data, string $key, int $max = 255): ?string
    {
        if (!array_key_exists($key, $data) || $data[$key] === null || $data[$key] === '') {
            return null;
        }
        return self::string($data, $key, 0, $max);
    }

    public static function date(string $value): string
    {
        $date = \DateTimeImmutable::createFromFormat('!Y-m-d', $value);
        $errors = \DateTimeImmutable::getLastErrors();
        if (
            !preg_match('/^\d{4}-\d{2}-\d{2}$/', $value)
            || $date === false
            || $date->format('Y-m-d') !== $value
            || ($errors !== false && ($errors['warning_count'] > 0 || $errors['error_count'] > 0))
        ) {
            Response::error('Ungültiges Datum.', 422);
        }
        return $value;
    }
}
