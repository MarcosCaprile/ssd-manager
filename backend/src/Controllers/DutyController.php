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
        Response::json($this->duties->history($auth));
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
}
