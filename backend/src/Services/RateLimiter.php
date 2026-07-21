<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Config;
use PDO;

final class RateLimiter
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function tooManyLoginAttempts(string $identifier, string $ip): bool
    {
        $window = Config::int('RATE_LIMIT_LOGIN_WINDOW_MINUTES', 15);
        $max = Config::int('RATE_LIMIT_LOGIN_ATTEMPTS', 8);
        $statement = $this->pdo->prepare(
            'SELECT COUNT(*) FROM login_attempts
             WHERE identifier = :identifier AND ip_address = :ip
             AND success = 0 AND attempted_at >= (UTC_TIMESTAMP() - INTERVAL :window MINUTE)'
        );
        $statement->bindValue(':identifier', mb_strtolower($identifier));
        $statement->bindValue(':ip', $ip);
        $statement->bindValue(':window', $window, PDO::PARAM_INT);
        $statement->execute();
        return (int) $statement->fetchColumn() >= $max;
    }

    public function recordLogin(string $identifier, string $ip, bool $success): void
    {
        $statement = $this->pdo->prepare(
            'INSERT INTO login_attempts (identifier, ip_address, success, attempted_at)
             VALUES (:identifier, :ip, :success, UTC_TIMESTAMP())'
        );
        $statement->execute([
            'identifier' => mb_strtolower($identifier),
            'ip' => $ip,
            'success' => $success ? 1 : 0,
        ]);
    }
}
