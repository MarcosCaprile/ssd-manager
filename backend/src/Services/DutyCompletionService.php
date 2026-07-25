<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Config;
use PDO;

final class DutyCompletionService
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function markPastPlannedAsCompleted(?int $schoolId = null, ?int $userId = null): int
    {
        $timezone = Config::env('SCHOOL_TIMEZONE', 'Europe/Berlin') ?? 'Europe/Berlin';
        $today = (new \DateTimeImmutable('today', new \DateTimeZone($timezone)))->format('Y-m-d');
        $sql = 'UPDATE duty_assignments da
                JOIN duty_days dd ON dd.id = da.duty_day_id
                SET da.status = "completed", da.completed_at = UTC_TIMESTAMP(), da.updated_at = UTC_TIMESTAMP()
                WHERE da.status = "planned" AND dd.duty_date < :today';
        $parameters = ['today' => $today];
        if ($schoolId !== null) {
            $sql .= ' AND dd.school_id = :school_id';
            $parameters['school_id'] = $schoolId;
        }
        if ($userId !== null) {
            $sql .= ' AND da.user_id = :user_id';
            $parameters['user_id'] = $userId;
        }
        $statement = $this->pdo->prepare($sql);
        $statement->execute($parameters);
        return $statement->rowCount();
    }
}
