<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Core\Database;

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "This script must be run from CLI.\n");
    exit(1);
}

$migrationFiles = glob(dirname(__DIR__) . '/database/migrations/*.sql');
if ($migrationFiles === false || $migrationFiles === []) {
    fwrite(STDERR, "No database migrations found.\n");
    exit(1);
}

sort($migrationFiles, SORT_STRING);
$pdo = Database::connection();

foreach ($migrationFiles as $migrationFile) {
    $sql = trim((string) file_get_contents($migrationFile));
    if ($sql === '') {
        continue;
    }

    $pdo->exec($sql);
    echo 'Applied ' . basename($migrationFile) . PHP_EOL;
}
