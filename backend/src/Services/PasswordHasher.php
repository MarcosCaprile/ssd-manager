<?php

declare(strict_types=1);

namespace App\Services;

final class PasswordHasher
{
    public static function hash(string $password): string
    {
        $algorithm = defined('PASSWORD_ARGON2ID') ? PASSWORD_ARGON2ID : PASSWORD_BCRYPT;
        return password_hash($password, $algorithm);
    }
}
