<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Core\Request;
use App\Core\Response;
use App\Services\AuthContext;
use App\Services\AuthService;

final class AuthController
{
    public function __construct(private readonly AuthService $auth)
    {
    }

    /**
     * @param array<string,string> $params
     */
    public function login(Request $request, array $params, ?AuthContext $auth): never
    {
        Response::json($this->auth->login($request->json(), $request->ip()));
    }

    /**
     * @param array<string,string> $params
     */
    public function refresh(Request $request, array $params, ?AuthContext $auth): never
    {
        Response::json($this->auth->refresh($request->json()));
    }

    /**
     * @param array<string,string> $params
     */
    public function logout(Request $request, array $params, AuthContext $auth): never
    {
        $this->auth->logout($auth);
        Response::json(['ok' => true]);
    }

    /**
     * @param array<string,string> $params
     */
    public function session(Request $request, array $params, AuthContext $auth): never
    {
        Response::json(['user' => $this->auth->publicUser($auth->user)]);
    }

    /**
     * @param array<string,string> $params
     */
    public function deviceToken(Request $request, array $params, AuthContext $auth): never
    {
        $data = $request->json();
        $this->auth->updateFirebaseToken($auth, isset($data['firebase_token']) ? (string) $data['firebase_token'] : null);
        Response::json(['ok' => true]);
    }

    /**
     * @param array<string,string> $params
     */
    public function changePassword(Request $request, array $params, AuthContext $auth): never
    {
        $user = $this->auth->changePassword($auth, $request->json());
        Response::json(['user' => $user]);
    }
}
