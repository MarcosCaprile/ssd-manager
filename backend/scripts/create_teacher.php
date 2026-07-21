<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Core\Config;
use App\Core\Database;
use App\Services\PasswordHasher;

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "This script must be run from CLI.\n");
    exit(1);
}

[$script, $firstName, $lastName, $username, $email, $password] = array_pad($argv, 6, null);
if (!$firstName || !$lastName || !$username || !$email || !$password || strlen($password) < 10) {
    fwrite(STDERR, "Usage: php backend/scripts/create_teacher.php FIRST LAST USERNAME EMAIL PASSWORD\n");
    fwrite(STDERR, "Password must be at least 10 characters.\n");
    exit(1);
}

$pdo = Database::connection();
$statement = $pdo->prepare(
    'INSERT INTO users
     (school_id, first_name, last_name, username, email, password_hash, role, status, must_change_password, created_at, updated_at)
     VALUES
     (:school_id, :first_name, :last_name, :username, :email, :password_hash, "teacher", "active", 1, UTC_TIMESTAMP(), UTC_TIMESTAMP())'
);
$statement->execute([
    'school_id' => Config::int('DEFAULT_SCHOOL_ID', 1),
    'first_name' => $firstName,
    'last_name' => $lastName,
    'username' => $username,
    'email' => mb_strtolower($email),
    'password_hash' => PasswordHasher::hash($password),
]);

echo "Teacher account created with id " . $pdo->lastInsertId() . PHP_EOL;
