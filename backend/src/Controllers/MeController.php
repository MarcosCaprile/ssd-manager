<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Core\Request;
use App\Core\Response;
use App\Services\AuthContext;
use App\Services\AuthService;
use App\Services\UserService;

final class MeController
{
    public function __construct(
        private readonly UserService $users,
        private readonly AuthService $authService,
    ) {
    }

    /**
     * @param array<string,string> $params
     */
    public function profile(Request $request, array $params, AuthContext $auth): never
    {
        Response::json($this->authService->publicUser($auth->user));
    }

    /**
     * @param array<string,string> $params
     */
    public function statistics(Request $request, array $params, AuthContext $auth): never
    {
        Response::json($this->users->statistics($auth, $auth->userId()));
    }

    /**
     * @param array<string,string> $params
     */
    public function devices(Request $request, array $params, AuthContext $auth): never
    {
        Response::json($this->users->devices($auth));
    }

    /**
     * @param array<string,string> $params
     */
    public function revokeDevice(Request $request, array $params, AuthContext $auth): never
    {
        $this->authService->revokeDevice($auth, (int) $params['id']);
        Response::json(['ok' => true]);
    }

    /**
     * @param array<string,string> $params
     */
    public function revokeOtherDevices(Request $request, array $params, AuthContext $auth): never
    {
        $this->authService->revokeOtherDevices($auth);
        Response::json(['ok' => true]);
    }
}
