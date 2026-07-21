<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Core\Database;

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "This script must be run from CLI.\n");
    exit(1);
}

[$script, $name, $slug] = array_pad($argv, 3, null);
$name = trim((string) $name);
$slug = strtolower(trim((string) $slug));

if (
    $name === ''
    || mb_strlen($name) > 180
    || !preg_match('/^[a-z0-9]+(?:-[a-z0-9]+)*$/', $slug)
    || strlen($slug) > 120
) {
    fwrite(STDERR, "Usage: php backend/scripts/create_school.php NAME SLUG\n");
    fwrite(STDERR, "SLUG may contain lowercase letters, numbers, and hyphens.\n");
    exit(1);
}

$pdo = Database::connection();
$statement = $pdo->prepare(
    'INSERT INTO schools (name, slug, active, created_at, updated_at)
     VALUES (:name, :slug, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP())'
);

try {
    $statement->execute(['name' => $name, 'slug' => $slug]);
} catch (PDOException $exception) {
    if ((string) $exception->getCode() === '23000') {
        fwrite(STDERR, "A school with this slug already exists.\n");
        exit(1);
    }
    throw $exception;
}

echo 'School created with id ' . $pdo->lastInsertId() . PHP_EOL;
