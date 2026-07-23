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
$pdo->exec(
    'CREATE TABLE IF NOT EXISTS schema_migrations (
        filename VARCHAR(255) NOT NULL PRIMARY KEY,
        applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'
);

foreach ($migrationFiles as $migrationFile) {
    $filename = basename($migrationFile);
    $check = $pdo->prepare('SELECT filename FROM schema_migrations WHERE filename = :filename LIMIT 1');
    $check->execute(['filename' => $filename]);
    if ($check->fetchColumn()) {
        echo 'Skipped ' . $filename . PHP_EOL;
        continue;
    }

    $sql = trim((string) file_get_contents($migrationFile));
    if ($sql === '') {
        continue;
    }

    $pdo->exec($sql);
    $record = $pdo->prepare('INSERT INTO schema_migrations (filename) VALUES (:filename)');
    $record->execute(['filename' => $filename]);
    echo 'Applied ' . $filename . PHP_EOL;
}
