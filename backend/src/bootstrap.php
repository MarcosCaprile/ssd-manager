<?php

declare(strict_types=1);

use App\Core\Config;

spl_autoload_register(function (string $class): void {
    $prefix = 'App\\';
    if (!str_starts_with($class, $prefix)) {
        return;
    }
    $relative = str_replace('\\', DIRECTORY_SEPARATOR, substr($class, strlen($prefix)));
    $file = __DIR__ . DIRECTORY_SEPARATOR . $relative . '.php';
    if (is_file($file)) {
        require $file;
    }
});

$envFile = dirname(__DIR__) . '/.env';
if (is_file($envFile)) {
    foreach (file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if (str_starts_with(trim($line), '#') || !str_contains($line, '=')) {
            continue;
        }
        [$key, $value] = explode('=', $line, 2);
        $key = trim($key);
        if (
            (!array_key_exists($key, $_ENV) || $_ENV[$key] === '')
            && (getenv($key) === false || getenv($key) === '')
        ) {
            $_ENV[$key] = trim($value);
        }
    }
}

date_default_timezone_set(Config::env('SCHOOL_TIMEZONE', 'Europe/Berlin'));

set_exception_handler(function (Throwable $exception): void {
    error_log($exception->getMessage());
    if (PHP_SAPI === 'cli') {
        fwrite(STDERR, "Command failed. See the error log for details.\n");
        exit(1);
    }
    \App\Core\Response::error('Ein unerwarteter Serverfehler ist aufgetreten.', 500);
});
