<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Core\Config;
use App\Core\Request;
use App\Core\Response;
use App\Services\DatabaseBackupService;
use PDO;

final class BackupController
{
    public function __construct(private readonly PDO $pdo, private readonly DatabaseBackupService $service)
    {
    }

    public function run(Request $request): never
    {
        $this->authorize($request);
        set_time_limit(600);
        $result = $this->service->run();
        Response::json([
            'status' => 'ok',
            'filename' => $result['filename'],
            'encrypted_bytes' => $result['encrypted_bytes'],
            'deleted_expired_files' => $result['deleted_expired_files'],
        ]);
    }

    public function status(Request $request): never
    {
        $this->authorize($request);
        $row = $this->pdo->query(
            'SELECT status, filename, encrypted_bytes, started_at, finished_at, error_code
             FROM backup_runs ORDER BY id DESC LIMIT 1'
        )->fetch();
        Response::json($row ?: ['status' => 'never_run']);
    }

    private function authorize(Request $request): void
    {
        $expected = Config::env('BACKUP_CRON_SECRET', '') ?? '';
        $provided = $request->query('secret') ?? '';
        if ($expected === '' || $provided === '' || !hash_equals($expected, $provided)) {
            Response::error('Nicht autorisiert.', 401);
        }
    }
}
