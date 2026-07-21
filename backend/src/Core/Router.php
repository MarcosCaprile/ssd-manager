<?php

declare(strict_types=1);

namespace App\Core;

use App\Services\AuthContext;
use App\Services\AuthService;

final class Router
{
    /**
     * @var array<int,array{method:string,pattern:string,handler:callable,auth:bool}>
     */
    private array $routes = [];

    public function __construct(private readonly AuthService $authService)
    {
    }

    public function add(string $method, string $pattern, callable $handler, bool $requiresAuth = true): void
    {
        $this->routes[] = [
            'method' => strtoupper($method),
            'pattern' => trim($pattern, '/'),
            'handler' => $handler,
            'auth' => $requiresAuth,
        ];
    }

    public function dispatch(): never
    {
        $request = new Request();
        foreach ($this->routes as $route) {
            if ($route['method'] !== $request->method()) {
                continue;
            }
            $params = $this->match($route['pattern'], $request->path());
            if ($params === null) {
                continue;
            }
            $auth = $route['auth'] ? $this->authService->requireAuth($request) : null;
            ($route['handler'])($request, $params, $auth);
        }
        Response::error('Endpunkt nicht gefunden.', 404);
    }

    /**
     * @return array<string,string>|null
     */
    private function match(string $pattern, string $path): ?array
    {
        $patternParts = $pattern === '' ? [] : explode('/', trim($pattern, '/'));
        $pathParts = $path === '' ? [] : explode('/', trim($path, '/'));
        if (count($patternParts) !== count($pathParts)) {
            return null;
        }
        $params = [];
        foreach ($patternParts as $index => $part) {
            if (preg_match('/^\{([a-zA-Z_][a-zA-Z0-9_]*)\}$/', $part, $match)) {
                $params[$match[1]] = rawurldecode($pathParts[$index]);
                continue;
            }
            if ($part !== $pathParts[$index]) {
                return null;
            }
        }
        return $params;
    }
}
