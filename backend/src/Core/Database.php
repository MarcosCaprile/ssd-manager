<?php

declare(strict_types=1);

namespace App\Core;

use PDO;

final class Database
{
    private static ?PDO $connection = null;

    public static function connection(): PDO
    {
        if (self::$connection instanceof PDO) {
            return self::$connection;
        }

        $host = Config::env('DB_HOST', '127.0.0.1');
        $port = Config::env('DB_PORT', '3306');
        $database = Config::env('DB_DATABASE', 'ssd_manager');
        $charset = Config::env('DB_CHARSET', 'utf8mb4');
        $dsn = "mysql:host={$host};port={$port};dbname={$database};charset={$charset}";

        self::$connection = new PDO($dsn, Config::env('DB_USERNAME', 'root'), Config::env('DB_PASSWORD', ''), [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);

        return self::$connection;
    }
}
