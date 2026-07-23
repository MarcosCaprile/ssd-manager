<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Config;
use App\Core\Response;
use PDO;

final class DutyService
{
    private DutyRules $rules;
    private AuditLogger $audit;

    public function __construct(
        private readonly PDO $pdo,
        private readonly NotificationService $notifications,
    ) {
        $this->rules = new DutyRules(Config::env('SCHOOL_TIMEZONE', 'Europe/Berlin') ?? 'Europe/Berlin');
        $this->audit = new AuditLogger($pdo);
    }

    /**
     * @return array<int,array<string,mixed>>
     */
    public function upcoming(AuthContext $auth): array
    {
        $today = new \DateTimeImmutable('today', new \DateTimeZone(Config::env('SCHOOL_TIMEZONE', 'Europe/Berlin') ?? 'Europe/Berlin'));
        $days = [];
        for ($i = 0; $i < 14; $i++) {
            $date = $today->modify("+{$i} days")->format('Y-m-d');
            if ($this->rules->isWeekend($date)) {
                $dayId = $this->findDutyDayId($auth->schoolId(), $date);
                if ($dayId !== null && $this->isExplicitWeekendDuty($dayId, $auth->schoolId())) {
                    $days[] = $this->serializeDutyDay($dayId, $auth->schoolId());
                }
                continue;
            }
            $dayId = $this->ensureDutyDay($auth->schoolId(), $date);
            $days[] = $this->serializeDutyDay($dayId, $auth->schoolId());
        }
        return $days;
    }

    /**
     * @return array<int,array<string,mixed>>
     */
    public function history(AuthContext $auth, ?string $date = null): array
    {
        $dateFilter = $date === null ? '' : ' AND duty_date = :date';
        $statement = $this->pdo->prepare(
            'SELECT id FROM duty_days
             WHERE school_id = :school_id AND duty_date >= (CURRENT_DATE - INTERVAL 1 YEAR)
               AND duty_date < CURRENT_DATE
               AND (WEEKDAY(duty_date) < 5 OR title IS NOT NULL OR is_closed = 1)
               ' . $dateFilter . '
             ORDER BY duty_date DESC'
        );
        $parameters = ['school_id' => $auth->schoolId()];
        if ($date !== null) {
            $parameters['date'] = $date;
        }
        $statement->execute($parameters);
        return array_map(
            fn (array $row) => $this->serializeDutyDay((int) $row['id'], $auth->schoolId()),
            $statement->fetchAll()
        );
    }

    /**
     * @return array<string,mixed>
     */
    public function createDay(
        AuthContext $auth,
        string $date,
        int $capacity,
        ?string $title,
        ?string $description,
    ): array {
        $this->requireManager($auth);
        if ($this->findDutyDayId($auth->schoolId(), $date) !== null) {
            Response::error('Für dieses Datum ist bereits ein Diensttag oder Ausfall eingetragen.', 409);
        }

        $statement = $this->pdo->prepare(
            'INSERT INTO duty_days
             (school_id, duty_date, title, description, capacity, is_active, is_closed, created_at, updated_at)
             VALUES (:school_id, :date, :title, :description, :capacity, 1, 0, UTC_TIMESTAMP(), UTC_TIMESTAMP())'
        );
        try {
            $statement->execute([
                'school_id' => $auth->schoolId(),
                'date' => $date,
                'title' => $title,
                'description' => $description,
                'capacity' => $capacity,
            ]);
        } catch (\PDOException $exception) {
            if ((string) $exception->getCode() === '23000') {
                Response::error('Für dieses Datum ist bereits ein Diensttag oder Ausfall eingetragen.', 409);
            }
            throw $exception;
        }
        $dayId = (int) $this->pdo->lastInsertId();
        $this->audit->log(
            $auth->schoolId(),
            $auth->userId(),
            'duty.day_created',
            null,
            'duty_day',
            $dayId,
            ['date' => $date, 'capacity' => $capacity, 'title' => $title]
        );
        return $this->serializeDutyDay($dayId, $auth->schoolId());
    }

    /**
     * @return array<string,mixed>
     */
    public function updateDay(
        AuthContext $auth,
        string $date,
        int $capacity,
        ?string $title,
        ?string $description,
        bool $isClosed,
    ): array {
        $this->requireManager($auth);
        $dayId = $this->findDutyDayId($auth->schoolId(), $date);
        if ($dayId === null) {
            Response::error('Diensttag wurde nicht gefunden.', 404);
        }
        if ($this->rules->isWeekend($date) && trim((string) $title) === '') {
            Response::error('Ein Diensttag am Wochenende benötigt einen Namen.', 422);
        }

        $this->pdo->beginTransaction();
        try {
            $this->lockDutyDay($dayId, $auth->schoolId());
            $planned = $this->plannedCount($dayId);
            if ($isClosed && $planned > 0) {
                $this->pdo->rollBack();
                Response::error('Ein Tag mit eingetragenen Sanis kann nicht als Ausfall markiert werden.', 409);
            }
            if (!$isClosed && $capacity < $planned) {
                $this->pdo->rollBack();
                Response::error("Die benötigte Anzahl kann nicht unter die {$planned} bestehenden Eintragungen gesetzt werden.", 409);
            }

            $statement = $this->pdo->prepare(
                'UPDATE duty_days
                 SET title = :title, description = :description, capacity = :capacity,
                     is_active = :is_active, is_closed = :is_closed, updated_at = UTC_TIMESTAMP()
                 WHERE id = :id AND school_id = :school_id'
            );
            $statement->execute([
                'title' => $title,
                'description' => $description,
                'capacity' => $capacity,
                'is_active' => $isClosed ? 0 : 1,
                'is_closed' => $isClosed ? 1 : 0,
                'id' => $dayId,
                'school_id' => $auth->schoolId(),
            ]);
            $this->audit->log(
                $auth->schoolId(),
                $auth->userId(),
                'duty.day_updated',
                null,
                'duty_day',
                $dayId,
                [
                    'date' => $date,
                    'capacity' => $capacity,
                    'title' => $title,
                    'is_closed' => $isClosed,
                ]
            );
            $this->pdo->commit();
        } catch (\Throwable $exception) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $exception;
        }
        return $this->serializeDutyDay($dayId, $auth->schoolId());
    }

    /**
     * @return array{created_days:int,start_date:string,end_date:string}
     */
    public function createClosureRange(
        AuthContext $auth,
        string $startDate,
        string $endDate,
        string $name,
        ?string $description,
    ): array {
        $this->requireManager($auth);
        $start = new \DateTimeImmutable($startDate);
        $end = new \DateTimeImmutable($endDate);
        if ($end < $start) {
            Response::error('Das Enddatum darf nicht vor dem Startdatum liegen.', 422);
        }
        if ((int) $start->diff($end)->format('%a') > 366) {
            Response::error('Ein Ausfallzeitraum darf höchstens 366 Tage umfassen.', 422);
        }

        $dates = [];
        for ($date = $start; $date <= $end; $date = $date->modify('+1 day')) {
            $value = $date->format('Y-m-d');
            if (!$this->rules->isWeekend($value)) {
                $dates[] = $value;
            }
        }
        if ($dates === []) {
            Response::error('Der gewählte Zeitraum enthält keinen Schultag.', 422);
        }

        $this->pdo->beginTransaction();
        try {
            $dayIds = [];
            foreach ($dates as $date) {
                $dayId = $this->ensureDutyDay($auth->schoolId(), $date);
                $this->lockDutyDay($dayId, $auth->schoolId());
                $planned = $this->plannedCount($dayId);
                if ($planned > 0) {
                    $this->pdo->rollBack();
                    Response::error(
                        'Der Ausfall kann nicht gespeichert werden, weil am ' . $this->humanDate($date) . ' bereits Sanis eingetragen sind.',
                        409
                    );
                }
                $dayIds[] = $dayId;
            }

            $statement = $this->pdo->prepare(
                'UPDATE duty_days
                 SET title = :title, description = :description, is_active = 0, is_closed = 1,
                     updated_at = UTC_TIMESTAMP()
                 WHERE id = :id AND school_id = :school_id'
            );
            foreach ($dayIds as $dayId) {
                $statement->execute([
                    'title' => $name,
                    'description' => $description,
                    'id' => $dayId,
                    'school_id' => $auth->schoolId(),
                ]);
            }

            $this->audit->log(
                $auth->schoolId(),
                $auth->userId(),
                'duty.closure_range_created',
                null,
                'duty_day',
                $dayIds[0],
                [
                    'start_date' => $startDate,
                    'end_date' => $endDate,
                    'name' => $name,
                    'weekday_count' => count($dayIds),
                ]
            );
            $this->pdo->commit();
        } catch (\Throwable $exception) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $exception;
        }

        return [
            'created_days' => count($dates),
            'start_date' => $startDate,
            'end_date' => $endDate,
        ];
    }

    /**
     * @return array<string,mixed>
     */
    public function resetDay(AuthContext $auth, string $date): array
    {
        $this->requireManager($auth);
        $dayId = $this->findDutyDayId($auth->schoolId(), $date);
        if ($dayId === null) {
            Response::error('Für dieses Datum gibt es keinen besonderen Eintrag.', 404);
        }

        $this->pdo->beginTransaction();
        try {
            $this->lockDutyDay($dayId, $auth->schoolId());
            $isWeekend = $this->rules->isWeekend($date);
            $planned = $this->plannedCount($dayId);
            if ($isWeekend && $planned > 0) {
                $this->pdo->rollBack();
                Response::error(
                    'Entferne zuerst alle eingetragenen Sanis, bevor du diesen Wochenenddienst löschst.',
                    409
                );
            }
            if ($isWeekend) {
                $this->pdo->prepare(
                    'DELETE FROM duty_days WHERE id = :id AND school_id = :school_id'
                )->execute([
                    'id' => $dayId,
                    'school_id' => $auth->schoolId(),
                ]);
                $this->audit->log(
                    $auth->schoolId(),
                    $auth->userId(),
                    'duty.weekend_event_removed',
                    null,
                    'duty_day',
                    $dayId,
                    ['date' => $date]
                );
                $this->pdo->commit();
                return [
                    'date' => $date,
                    'title' => null,
                    'description' => null,
                    'capacity' => Config::int('DUTY_CAPACITY', 3),
                    'is_active' => false,
                    'is_closed' => false,
                    'assignments' => [],
                ];
            }
            $capacity = max(Config::int('DUTY_CAPACITY', 3), $planned);
            $this->pdo->prepare(
                'UPDATE duty_days
                 SET title = NULL, description = NULL, capacity = :capacity,
                     is_active = :is_active, is_closed = 0, updated_at = UTC_TIMESTAMP()
                 WHERE id = :id AND school_id = :school_id'
            )->execute([
                'capacity' => $capacity,
                'is_active' => 1,
                'id' => $dayId,
                'school_id' => $auth->schoolId(),
            ]);
            $this->audit->log(
                $auth->schoolId(),
                $auth->userId(),
                'duty.day_reset',
                null,
                'duty_day',
                $dayId,
                ['date' => $date]
            );
            $this->pdo->commit();
        } catch (\Throwable $exception) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $exception;
        }
        return $this->serializeDutyDay($dayId, $auth->schoolId());
    }

    /**
     * @return array{reset_days:int,start_date:string,end_date:string}
     */
    public function resetClosureRange(
        AuthContext $auth,
        string $startDate,
        string $endDate,
    ): array {
        $this->requireManager($auth);
        $start = new \DateTimeImmutable($startDate);
        $end = new \DateTimeImmutable($endDate);
        if ($end < $start) {
            Response::error('Das Enddatum darf nicht vor dem Startdatum liegen.', 422);
        }
        if ((int) $start->diff($end)->format('%a') > 366) {
            Response::error('Ein Zeitraum darf höchstens 366 Tage umfassen.', 422);
        }

        $reset = 0;
        $this->pdo->beginTransaction();
        try {
            for ($date = $start; $date <= $end; $date = $date->modify('+1 day')) {
                $value = $date->format('Y-m-d');
                if ($this->rules->isWeekend($value)) {
                    continue;
                }
                $dayId = $this->findDutyDayId($auth->schoolId(), $value);
                if ($dayId === null) {
                    continue;
                }
                $day = $this->lockDutyDay($dayId, $auth->schoolId());
                if (!(bool) $day['is_closed']) {
                    continue;
                }
                $capacity = max(Config::int('DUTY_CAPACITY', 3), $this->plannedCount($dayId));
                $this->pdo->prepare(
                    'UPDATE duty_days
                     SET title = NULL, description = NULL, capacity = :capacity,
                         is_active = 1, is_closed = 0, updated_at = UTC_TIMESTAMP()
                     WHERE id = :id AND school_id = :school_id'
                )->execute([
                    'capacity' => $capacity,
                    'id' => $dayId,
                    'school_id' => $auth->schoolId(),
                ]);
                $reset++;
            }
            $this->audit->log(
                $auth->schoolId(),
                $auth->userId(),
                'duty.closure_range_reset',
                null,
                'duty_day',
                null,
                [
                    'start_date' => $startDate,
                    'end_date' => $endDate,
                    'weekday_count' => $reset,
                ]
            );
            $this->pdo->commit();
        } catch (\Throwable $exception) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $exception;
        }
        if ($reset === 0) {
            Response::error('Im gewählten Zeitraum wurde kein Ausfall gefunden.', 404);
        }
        return [
            'reset_days' => $reset,
            'start_date' => $startDate,
            'end_date' => $endDate,
        ];
    }

    /**
     * @return array<string,mixed>
     */
    public function details(AuthContext $auth, string $date): array
    {
        if ($this->rules->isWeekend($date)) {
            $dayId = $this->findDutyDayId($auth->schoolId(), $date);
            if ($dayId !== null) {
                return $this->serializeDutyDay($dayId, $auth->schoolId());
            }
            return [
                'date' => $date,
                'title' => null,
                'description' => null,
                'capacity' => Config::int('DUTY_CAPACITY', 3),
                'is_active' => false,
                'is_closed' => false,
                'assignments' => [],
            ];
        }
        return $this->serializeDutyDay($this->ensureDutyDay($auth->schoolId(), $date), $auth->schoolId());
    }

    public function selfAssign(AuthContext $auth, string $date): void
    {
        if (!$auth->canAssignSelfToDuty()) {
            Response::error('Mit deiner Rolle kannst du dich nicht für einen Sanitätsdienst eintragen.', 403);
        }
        if (
            !$this->rules->isWithinUpcomingWindow($date)
            || ($this->rules->isWeekend($date) && !$this->hasActiveWeekendEvent($auth->schoolId(), $date))
        ) {
            Response::error('Dieser Dienst kann nicht gebucht werden.', 422);
        }
        $this->assign($auth, $date, $auth->userId(), 'self', $auth->userId());
    }

    public function selfCancel(AuthContext $auth, string $date): void
    {
        if (!$this->rules->canCancelRegularly($date)) {
            Response::error('Unterhalb der 48-Stunden-Grenze ist nur eine Krankmeldung möglich.', 422);
        }
        $assignment = $this->plannedAssignmentForUser($auth->schoolId(), $date, $auth->userId());
        if (!$assignment) {
            Response::error('Für diesen Tag ist keine aktive Eintragung vorhanden.', 404);
        }
        $this->pdo->prepare(
            'UPDATE duty_assignments
             SET status = "cancelled", cancelled_at = UTC_TIMESTAMP(), updated_at = UTC_TIMESTAMP()
             WHERE id = :id'
        )->execute(['id' => $assignment['id']]);
        $this->audit->log($auth->schoolId(), $auth->userId(), 'duty.self_cancelled', $auth->userId(), 'duty_assignment', (int) $assignment['id']);
        $this->notifyOpenSlot($auth->schoolId(), (int) $assignment['duty_day_id'], $date, 'regular_cancel');
    }

    public function sickReport(AuthContext $auth, string $date): void
    {
        if (!$this->rules->canReportSick($date)) {
            Response::error('Eine Krankmeldung ist nur innerhalb der letzten 48 Stunden möglich.', 422);
        }
        $assignment = $this->plannedAssignmentForUser($auth->schoolId(), $date, $auth->userId());
        if (!$assignment) {
            Response::error('Für diesen Tag ist keine aktive Eintragung vorhanden.', 404);
        }
        $this->pdo->prepare(
            'UPDATE duty_assignments
             SET status = "sick_reported", sick_reported_at = UTC_TIMESTAMP(), updated_at = UTC_TIMESTAMP()
             WHERE id = :id'
        )->execute(['id' => $assignment['id']]);
        $this->audit->log($auth->schoolId(), $auth->userId(), 'duty.sick_reported', $auth->userId(), 'duty_assignment', (int) $assignment['id']);
        $this->notifications->notifyUsersByRole(
            $auth->schoolId(),
            ['sanitaeter', 'sani_leitung', 'teacher'],
            'duty_sick_reported',
            'Dringend: Krankmeldung im SSD',
            'Für ' . $this->humanDate($date) . ' ist kurzfristig ein Platz frei geworden.',
            'sick:' . $date,
            (int) $assignment['duty_day_id'],
            null,
            [$auth->userId()],
            ['route' => 'duty', 'date' => $date, 'priority' => 'high']
        );
    }

    public function adminAssign(AuthContext $auth, string $date, int $userId): void
    {
        if (!$auth->canManageDuties()) {
            Response::error('Keine Berechtigung.', 403);
        }
        if ($this->rules->isWeekend($date) && !$this->hasActiveWeekendEvent($auth->schoolId(), $date)) {
            Response::error('An diesem Wochenende ist kein Diensttag eingetragen.', 422);
        }
        $target = $this->findActiveAssignableUser($auth->schoolId(), $userId);
        $this->assign($auth, $date, $userId, $auth->role() === 'teacher' ? 'teacher' : 'sani_leitung', $auth->userId());
        $dayId = $this->ensureDutyDay($auth->schoolId(), $date);
        $this->notifications->notifyUser(
            $auth->schoolId(),
            $userId,
            'duty_admin_assigned',
            'Du wurdest für einen SSD-Dienst eingetragen',
            'Du wurdest für ' . $this->humanDate($date) . ' eingetragen.',
            'admin-assigned:' . $date . ':' . $userId . ':' . time(),
            $dayId,
            ['route' => 'duty', 'date' => $date]
        );
        unset($target);
    }

    public function adminRemove(AuthContext $auth, string $date, int $assignmentId): void
    {
        if (!$auth->canManageDuties()) {
            Response::error('Keine Berechtigung.', 403);
        }
        $statement = $this->pdo->prepare(
            'SELECT da.*, dd.duty_date, dd.school_id
             FROM duty_assignments da
             JOIN duty_days dd ON dd.id = da.duty_day_id
             WHERE da.id = :id AND dd.school_id = :school_id AND dd.duty_date = :date
               AND da.status = "planned"'
        );
        $statement->execute([
            'id' => $assignmentId,
            'school_id' => $auth->schoolId(),
            'date' => $date,
        ]);
        $assignment = $statement->fetch();
        if (!$assignment) {
            Response::error('Eintragung wurde nicht gefunden.', 404);
        }
        $this->pdo->prepare(
            'UPDATE duty_assignments
             SET status = "admin_removed", cancelled_at = UTC_TIMESTAMP(), updated_at = UTC_TIMESTAMP()
             WHERE id = :id'
        )->execute(['id' => $assignmentId]);
        $this->audit->log($auth->schoolId(), $auth->userId(), 'duty.admin_removed', (int) $assignment['user_id'], 'duty_assignment', $assignmentId);
        $this->notifications->notifyUser(
            $auth->schoolId(),
            (int) $assignment['user_id'],
            'duty_admin_removed',
            'SSD-Dienst aktualisiert',
            'Du wurdest aus dem SSD-Dienst am ' . $this->humanDate($date) . ' entfernt.',
            'admin-removed:' . $assignmentId . ':' . time(),
            (int) $assignment['duty_day_id'],
            ['route' => 'duty', 'date' => $date]
        );
    }

    public function markPastPlannedAsCompleted(): int
    {
        $statement = $this->pdo->prepare(
            'UPDATE duty_assignments da
             JOIN duty_days dd ON dd.id = da.duty_day_id
             SET da.status = "completed", da.completed_at = UTC_TIMESTAMP(), da.updated_at = UTC_TIMESTAMP()
             WHERE da.status = "planned" AND dd.duty_date < CURRENT_DATE'
        );
        $statement->execute();
        return $statement->rowCount();
    }

    public function send48HourReminders(): int
    {
        $statement = $this->pdo->query(
            'SELECT dd.id, dd.school_id, dd.duty_date, dd.capacity,
                    SUM(CASE WHEN da.status = "planned" THEN 1 ELSE 0 END) AS occupied
             FROM duty_days dd
             LEFT JOIN duty_assignments da ON da.duty_day_id = dd.id
             WHERE dd.duty_date BETWEEN CURRENT_DATE + INTERVAL 1 DAY AND CURRENT_DATE + INTERVAL 2 DAY
               AND dd.is_active = 1 AND dd.is_closed = 0
             GROUP BY dd.id'
        );
        $count = 0;
        foreach ($statement->fetchAll() as $day) {
            $free = (int) $day['capacity'] - (int) $day['occupied'];
            if ($free <= 0) {
                continue;
            }
            $this->notifications->notifyUsersByRole(
                (int) $day['school_id'],
                ['sanitaeter', 'sani_leitung'],
                'duty_48h_open_slots',
                'Noch freie SSD-Dienste',
                'Für ' . $this->humanDate((string) $day['duty_date']) . " sind noch {$free} Plätze frei.",
                '48h:' . $day['id'],
                (int) $day['id'],
                null,
                [],
                ['route' => 'duty', 'date' => (string) $day['duty_date']]
            );
            $count++;
        }
        return $count;
    }

    private function assign(AuthContext $auth, string $date, int $userId, string $assignmentType, int $assignedBy): void
    {
        $this->pdo->beginTransaction();
        try {
            $dayId = $this->ensureDutyDay($auth->schoolId(), $date);
            $day = $this->lockDutyDay($dayId, $auth->schoolId());
            if (!(bool) $day['is_active'] || (bool) $day['is_closed']) {
                $this->pdo->rollBack();
                Response::error('Dieser Tag ist als Ausfall markiert und kann nicht belegt werden.', 409);
            }
            $count = $this->plannedCount($dayId);
            if ($count >= (int) $day['capacity']) {
                $this->pdo->rollBack();
                Response::error('Alle benötigten Plätze sind bereits belegt.', 409);
            }
            if ($this->hasPlannedAssignment($dayId, $userId)) {
                $this->pdo->rollBack();
                Response::error('Diese Person ist bereits eingetragen.', 409);
            }
            $statement = $this->pdo->prepare(
                'INSERT INTO duty_assignments
                 (duty_day_id, user_id, status, assigned_by_user_id, assignment_type, assigned_at, updated_at)
                 VALUES (:duty_day_id, :user_id, "planned", :assigned_by, :assignment_type, UTC_TIMESTAMP(), UTC_TIMESTAMP())'
            );
            $statement->execute([
                'duty_day_id' => $dayId,
                'user_id' => $userId,
                'assigned_by' => $assignedBy,
                'assignment_type' => $assignmentType,
            ]);
            $assignmentId = (int) $this->pdo->lastInsertId();
            $this->audit->log($auth->schoolId(), $auth->userId(), 'duty.assigned', $userId, 'duty_assignment', $assignmentId, [
                'date' => $date,
                'assignment_type' => $assignmentType,
            ]);
            $this->pdo->commit();
        } catch (\Throwable $exception) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $exception;
        }
    }

    private function ensureDutyDay(int $schoolId, string $date): int
    {
        $statement = $this->pdo->prepare(
            'SELECT id FROM duty_days WHERE school_id = :school_id AND duty_date = :date LIMIT 1'
        );
        $statement->execute(['school_id' => $schoolId, 'date' => $date]);
        $id = $statement->fetchColumn();
        if ($id) {
            return (int) $id;
        }
        $insert = $this->pdo->prepare(
            'INSERT INTO duty_days (school_id, duty_date, capacity, is_active, created_at, updated_at)
             VALUES (:school_id, :date, :capacity, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP())'
        );
        $insert->execute([
            'school_id' => $schoolId,
            'date' => $date,
            'capacity' => Config::int('DUTY_CAPACITY', 3),
        ]);
        return (int) $this->pdo->lastInsertId();
    }

    /**
     * @return array<string,mixed>
     */
    private function lockDutyDay(int $dayId, int $schoolId): array
    {
        $statement = $this->pdo->prepare(
            'SELECT * FROM duty_days WHERE id = :id AND school_id = :school_id FOR UPDATE'
        );
        $statement->execute(['id' => $dayId, 'school_id' => $schoolId]);
        $day = $statement->fetch();
        if (!$day) {
            Response::error('Diensttag wurde nicht gefunden.', 404);
        }
        return $day;
    }

    private function plannedCount(int $dayId): int
    {
        $statement = $this->pdo->prepare(
            'SELECT id FROM duty_assignments
             WHERE duty_day_id = :day_id AND status = "planned"
             FOR UPDATE'
        );
        $statement->execute(['day_id' => $dayId]);
        return count($statement->fetchAll());
    }

    private function hasPlannedAssignment(int $dayId, int $userId): bool
    {
        $statement = $this->pdo->prepare(
            'SELECT id FROM duty_assignments
             WHERE duty_day_id = :day_id AND user_id = :user_id AND status = "planned"
             LIMIT 1'
        );
        $statement->execute(['day_id' => $dayId, 'user_id' => $userId]);
        return (bool) $statement->fetchColumn();
    }

    /**
     * @return array<string,mixed>|null
     */
    private function plannedAssignmentForUser(int $schoolId, string $date, int $userId): ?array
    {
        $statement = $this->pdo->prepare(
            'SELECT da.*
             FROM duty_assignments da
             JOIN duty_days dd ON dd.id = da.duty_day_id
             WHERE dd.school_id = :school_id AND dd.duty_date = :date
               AND da.user_id = :user_id AND da.status = "planned"
             LIMIT 1'
        );
        $statement->execute([
            'school_id' => $schoolId,
            'date' => $date,
            'user_id' => $userId,
        ]);
        $row = $statement->fetch();
        return $row ?: null;
    }

    /**
     * @return array<string,mixed>
     */
    private function serializeDutyDay(int $dayId, int $schoolId): array
    {
        $day = $this->locklessDutyDay($dayId, $schoolId);
        $statement = $this->pdo->prepare(
            'SELECT da.*, CONCAT(u.first_name, " ", u.last_name) AS full_name
             FROM duty_assignments da
             JOIN users u ON u.id = da.user_id
             WHERE da.duty_day_id = :day_id
             ORDER BY da.assigned_at ASC'
        );
        $statement->execute(['day_id' => $dayId]);
        return [
            'date' => $day['duty_date'],
            'title' => $day['title'],
            'description' => $day['description'],
            'capacity' => (int) $day['capacity'],
            'is_active' => (bool) $day['is_active'],
            'is_closed' => (bool) $day['is_closed'],
            'assignments' => array_map(fn (array $assignment) => [
                'id' => (int) $assignment['id'],
                'user_id' => (int) $assignment['user_id'],
                'full_name' => $assignment['full_name'],
                'status' => $assignment['status'],
                'assignment_type' => $assignment['assignment_type'],
                'assigned_at' => $assignment['assigned_at'],
                'cancelled_at' => $assignment['cancelled_at'],
                'sick_reported_at' => $assignment['sick_reported_at'],
                'completed_at' => $assignment['completed_at'],
            ], $statement->fetchAll()),
        ];
    }

    /**
     * @return array<string,mixed>
     */
    private function locklessDutyDay(int $dayId, int $schoolId): array
    {
        $statement = $this->pdo->prepare('SELECT * FROM duty_days WHERE id = :id AND school_id = :school_id');
        $statement->execute(['id' => $dayId, 'school_id' => $schoolId]);
        $day = $statement->fetch();
        if (!$day) {
            Response::error('Diensttag wurde nicht gefunden.', 404);
        }
        return $day;
    }

    /**
     * @return array<string,mixed>
     */
    private function findActiveAssignableUser(int $schoolId, int $userId): array
    {
        $statement = $this->pdo->prepare(
            "SELECT * FROM users
             WHERE id = :id AND school_id = :school_id AND status = 'active'
               AND role IN ('sanitaeter', 'sani_leitung') AND deleted_at IS NULL
             LIMIT 1"
        );
        $statement->execute(['id' => $userId, 'school_id' => $schoolId]);
        $user = $statement->fetch();
        if (!$user) {
            Response::error('Diese Person kann nicht für Dienste eingetragen werden.', 422);
        }
        return $user;
    }

    private function notifyOpenSlot(int $schoolId, int $dayId, string $date, string $reason): void
    {
        $day = $this->locklessDutyDay($dayId, $schoolId);
        if (!(bool) $day['is_active'] || (bool) $day['is_closed']) {
            return;
        }
        $free = (int) $day['capacity'] - $this->plannedCount($dayId);
        if ($free <= 0) {
            return;
        }
        $this->notifications->notifyUsersByRole(
            $schoolId,
            ['sanitaeter', 'sani_leitung'],
            'duty_slot_available',
            'SSD-Platz frei geworden',
            'Für ' . $this->humanDate($date) . " sind {$free} Plätze frei.",
            'open-slot:' . $date . ':' . $reason . ':' . time(),
            $dayId,
            null,
            [],
            ['route' => 'duty', 'date' => $date]
        );
    }

    private function humanDate(string $date): string
    {
        return (new \DateTimeImmutable($date))->format('d.m.Y');
    }

    private function requireManager(AuthContext $auth): void
    {
        if (!$auth->canManageDuties()) {
            Response::error('Keine Berechtigung.', 403);
        }
    }

    private function hasActiveWeekendEvent(int $schoolId, string $date): bool
    {
        $dayId = $this->findDutyDayId($schoolId, $date);
        return $dayId !== null && $this->isExplicitWeekendDuty($dayId, $schoolId);
    }

    private function isExplicitWeekendDuty(int $dayId, int $schoolId): bool
    {
        $day = $this->locklessDutyDay($dayId, $schoolId);
        return trim((string) ($day['title'] ?? '')) !== ''
            && (bool) $day['is_active']
            && !(bool) $day['is_closed'];
    }

    private function findDutyDayId(int $schoolId, string $date): ?int
    {
        $statement = $this->pdo->prepare(
            'SELECT id FROM duty_days WHERE school_id = :school_id AND duty_date = :date LIMIT 1'
        );
        $statement->execute(['school_id' => $schoolId, 'date' => $date]);
        $id = $statement->fetchColumn();
        return $id === false ? null : (int) $id;
    }
}
