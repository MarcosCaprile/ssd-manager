<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Core\Request;
use App\Core\Response;
use App\Core\Validation;
use App\Services\AuthContext;
use App\Services\AuthService;
use App\Services\UserBulkService;
use App\Services\UserService;

final class UserController
{
    public function __construct(
        private readonly UserService $users,
        private readonly AuthService $auth,
        private readonly UserBulkService $bulkUsers,
    ) {
    }

    /**
     * @param array<string,string> $params
     */
    public function index(Request $request, array $params, AuthContext $auth): never
    {
        Response::json($this->users->list($auth));
    }

    /**
     * @param array<string,string> $params
     */
    public function store(Request $request, array $params, AuthContext $auth): never
    {
        $data = $request->json();
        foreach (['first_name', 'last_name', 'username', 'email', 'temporary_password'] as $field) {
            Validation::string($data, $field, $field === 'temporary_password' ? 10 : 1, 255);
        }
        $this->users->create($auth, $data);
        Response::json(['ok' => true], 201);
    }

    /**
     * @param array<string,string> $params
     */
    public function show(Request $request, array $params, AuthContext $auth): never
    {
        Response::json($this->users->profile($auth, (int) $params['id']));
    }

    /**
     * @param array<string,string> $params
     */
    public function update(Request $request, array $params, AuthContext $auth): never
    {
        Response::error('Profilbearbeitung ist für Version 1 nicht aktiviert.', 405);
    }

    /**
     * @param array<string,string> $params
     */
    public function deactivate(Request $request, array $params, AuthContext $auth): never
    {
        $this->users->deactivate($auth, (int) $params['id']);
        Response::json(['ok' => true]);
    }

    /**
     * @param array<string,string> $params
     */
    public function reactivate(Request $request, array $params, AuthContext $auth): never
    {
        $this->users->reactivate($auth, (int) $params['id']);
        Response::json(['ok' => true]);
    }

    /**
     * @param array<string,string> $params
     */
    public function markDeletion(Request $request, array $params, AuthContext $auth): never
    {
        $this->users->markDeletion($auth, (int) $params['id']);
        Response::json(['ok' => true]);
    }

    /**
     * @param array<string,string> $params
     */
    public function changeRole(Request $request, array $params, AuthContext $auth): never
    {
        $data = $request->json();
        $this->users->changeRole($auth, (int) $params['id'], (string) ($data['role'] ?? ''));
        Response::json(['ok' => true]);
    }

    /**
     * @param array<string,string> $params
     */
    public function validateBulk(Request $request, array $params, AuthContext $auth): never
    {
        $data = $request->json();
        $rows = $data['rows'] ?? null;
        if (!is_array($rows)) {
            Response::error('Die Bulk-Datei enthält keine gültige Zeilenliste.', 422);
        }
        Response::json($this->bulkUsers->validate($auth, $rows));
    }

    /**
     * @param array<string,string> $params
     */
    public function applyBulk(Request $request, array $params, AuthContext $auth): never
    {
        $data = $request->json();
        $rows = $data['rows'] ?? null;
        if (!is_array($rows)) {
            Response::error('Die Bulk-Datei enthält keine gültige Zeilenliste.', 422);
        }
        Response::json($this->bulkUsers->apply($auth, $rows));
    }
}
