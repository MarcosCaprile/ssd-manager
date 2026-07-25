<?php

declare(strict_types=1);

use App\Core\Config;
use App\Core\Database;
use App\Services\DutyCompletionService;

require dirname(__DIR__) . '/src/bootstrap.php';

$databaseHost = Config::env('DB_HOST', '127.0.0.1');
if (
    Config::env('APP_ENV') !== 'local'
    || !in_array($databaseHost, ['127.0.0.1', 'localhost', '::1'], true)
) {
    fwrite(STDERR, '[FAIL] Duty completion smoke test requires a local APP_ENV/database.' . PHP_EOL);
    exit(1);
}

$pdo = Database::connection();
$failure = null;
$pdo->beginTransaction();
try {
    $user = $pdo->query(
        "SELECT id, school_id FROM users
         WHERE status = 'active' AND role IN ('sanitaeter', 'sani_leitung')
         ORDER BY id LIMIT 1"
    )->fetch();
    if (!$user) {
        throw new RuntimeException('No active local sanitary test user exists.');
    }

    $timezone = Config::env('SCHOOL_TIMEZONE', 'Europe/Berlin') ?? 'Europe/Berlin';
    $today = new DateTimeImmutable('today', new DateTimeZone($timezone));
    $date = null;
    for ($offset = 30; $offset < 400; $offset++) {
        $candidate = $today->modify("-{$offset} days");
        if ((int) $candidate->format('N') > 5) {
            continue;
        }
        $value = $candidate->format('Y-m-d');
        $check = $pdo->prepare(
            'SELECT id FROM duty_days WHERE school_id = :school_id AND duty_date = :date'
        );
        $check->execute(['school_id' => $user['school_id'], 'date' => $value]);
        if (!$check->fetchColumn()) {
            $date = $value;
            break;
        }
    }
    if ($date === null) {
        throw new RuntimeException('No unused past weekday was available for the test.');
    }

    $day = $pdo->prepare(
        'INSERT INTO duty_days
         (school_id, duty_date, capacity, is_active, is_closed, created_at, updated_at)
         VALUES (:school_id, :date, 3, 1, 0, UTC_TIMESTAMP(), UTC_TIMESTAMP())'
    );
    $day->execute(['school_id' => $user['school_id'], 'date' => $date]);
    $dayId = (int) $pdo->lastInsertId();
    $assignment = $pdo->prepare(
        'INSERT INTO duty_assignments
         (duty_day_id, user_id, status, assignment_type, assigned_at, updated_at)
         VALUES (:day_id, :user_id, "planned", "self", UTC_TIMESTAMP(), UTC_TIMESTAMP())'
    );
    $assignment->execute(['day_id' => $dayId, 'user_id' => $user['id']]);
    $assignmentId = (int) $pdo->lastInsertId();

    $completed = (new DutyCompletionService($pdo))->markPastPlannedAsCompleted(
        (int) $user['school_id'],
        (int) $user['id']
    );
    $read = $pdo->prepare(
        'SELECT status, completed_at FROM duty_assignments WHERE id = :id'
    );
    $read->execute(['id' => $assignmentId]);
    $row = $read->fetch();
    if (
        $completed !== 1
        || ($row['status'] ?? null) !== 'completed'
        || ($row['completed_at'] ?? null) === null
    ) {
        throw new RuntimeException('Past planned duty was not materialized as completed.');
    }
    echo '[OK] past planned duty is materialized as completed' . PHP_EOL;
} catch (Throwable $exception) {
    $failure = $exception;
} finally {
    $pdo->rollBack();
}

if ($failure !== null) {
    fwrite(STDERR, '[FAIL] ' . $failure->getMessage() . PHP_EOL);
    exit(1);
}

echo 'Duty completion smoke test passed.' . PHP_EOL;
