<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Core\Request;
use App\Core\Response;
use App\Core\Validation;
use App\Services\AuthContext;
use App\Services\DutyService;

final class DutyController
{
    public function __construct(private readonly DutyService $duties)
    {
    }

    /**
     * @param array<string,string> $params
     */
    public function upcoming(Request $request, array $params, AuthContext $auth): never
    {
        Response::json($this->duties->upcoming($auth));
    }

    /**
     * @param array<string,string> $params
     */
    public function history(Request $request, array $params, AuthContext $auth): never
    {
        $date = $request->query('date');
        Response::json($this->duties->history($auth, $date === null ? null : Validation::date($date)));
    }

    /**
     * @param array<string,string> $params
     */
    public function create(Request $request, array $params, AuthContext $auth): never
    {
        $data = $request->json();
        Response::json($this->duties->createDay(
            $auth,
            Validation::date((string) ($data['date'] ?? '')),
            $this->capacity($data),
            Validation::optionalString($data, 'title', 180),
            Validation::optionalString($data, 'description', 1000),
        ), 201);
    }

    /**
     * @param array<string,string> $params
     */
    public function update(Request $request, array $params, AuthContext $auth): never
    {
        $data = $request->json();
        if (array_key_exists('is_closed', $data) && !is_bool($data['is_closed'])) {
            Response::error('Ungültige Eingabe: is_closed', 422);
        }
        Response::json($this->duties->updateDay(
            $auth,
            Validation::date($params['date']),
            $this->capacity($data),
            Validation::optionalString($data, 'title', 180),
            Validation::optionalString($data, 'description', 1000),
            (bool) ($data['is_closed'] ?? false),
        ));
    }

    /**
     * @param array<string,string> $params
     */
    public function createClosure(Request $request, array $params, AuthContext $auth): never
    {
        $data = $request->json();
        Response::json($this->duties->createClosureRange(
            $auth,
            Validation::date((string) ($data['start_date'] ?? '')),
            Validation::date((string) ($data['end_date'] ?? '')),
            Validation::string($data, 'name', 1, 180),
            Validation::optionalString($data, 'description', 1000),
        ), 201);
    }

    /**
     * @param array<string,string> $params
     */
    public function resetClosure(Request $request, array $params, AuthContext $auth): never
    {
        $data = $request->json();
        Response::json($this->duties->resetClosureRange(
            $auth,
            Validation::date((string) ($data['start_date'] ?? '')),
            Validation::date((string) ($data['end_date'] ?? '')),
        ));
    }

    /**
     * @param array<string,string> $params
     */
    public function reset(Request $request, array $params, AuthContext $auth): never
    {
        Response::json($this->duties->resetDay(
            $auth,
            Validation::date($params['date'])
        ));
    }

    /**
     * @param array<string,string> $params
     */
    public function details(Request $request, array $params, AuthContext $auth): never
    {
        Response::json($this->duties->details($auth, Validation::date($params['date'])));
    }

    /**
     * @param array<string,string> $params
     */
    public function selfAssign(Request $request, array $params, AuthContext $auth): never
    {
        $this->duties->selfAssign($auth, Validation::date($params['date']));
        Response::json(['ok' => true], 201);
    }

    /**
     * @param array<string,string> $params
     */
    public function selfCancel(Request $request, array $params, AuthContext $auth): never
    {
        $this->duties->selfCancel($auth, Validation::date($params['date']));
        Response::json(['ok' => true]);
    }

    /**
     * @param array<string,string> $params
     */
    public function sickReport(Request $request, array $params, AuthContext $auth): never
    {
        $this->duties->sickReport($auth, Validation::date($params['date']));
        Response::json(['ok' => true]);
    }

    /**
     * @param array<string,string> $params
     */
    public function adminAssign(Request $request, array $params, AuthContext $auth): never
    {
        $data = $request->json();
        $this->duties->adminAssign($auth, Validation::date($params['date']), (int) ($data['user_id'] ?? 0));
        Response::json(['ok' => true], 201);
    }

    /**
     * @param array<string,string> $params
     */
    public function adminRemove(Request $request, array $params, AuthContext $auth): never
    {
        $this->duties->adminRemove(
            $auth,
            Validation::date($params['date']),
            (int) $params['assignmentId']
        );
        Response::json(['ok' => true]);
    }

    /**
     * @param array<string,mixed> $data
     */
    private function capacity(array $data): int
    {
        $capacity = filter_var($data['capacity'] ?? null, FILTER_VALIDATE_INT);
        if ($capacity === false || $capacity < 1 || $capacity > 20) {
            Response::error('Die Anzahl benötigter Sanis muss zwischen 1 und 20 liegen.', 422);
        }
        return $capacity;
    }
}
