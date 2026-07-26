<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Config;
use PDO;
use RuntimeException;

final class DatabaseBackupService
{
    public function __construct(private readonly PDO $pdo, private readonly FtpsBackupStorage $storage)
    {
    }

    /** @return array{filename:string,encrypted_bytes:int,sha256:string,deleted_expired_files:int} */
    public function run(): array
    {
        $this->assertConfigured();
        $this->pdo->exec("DELETE FROM backup_runs WHERE started_at < UTC_TIMESTAMP() - INTERVAL 90 DAY");
        $this->pdo->exec("INSERT INTO backup_runs (status) VALUES ('running')");
        $runId = (int) $this->pdo->lastInsertId();
        $directory = sys_get_temp_dir() . '/ssd-manager-backup-' . bin2hex(random_bytes(8));
        if (!mkdir($directory, 0700)) {
            throw new RuntimeException('backup_temp_directory_failed');
        }
        $stamp = gmdate('Ymd\THis\Z');
        $base = 'ssd-manager-' . $stamp;
        $sql = $directory . '/' . $base . '.sql';
        $gzip = $sql . '.gz';
        $encrypted = $gzip . '.enc';
        $manifest = $directory . '/' . $base . '.manifest.json';

        try {
            $this->dumpDatabase($sql);
            $this->gzip($sql, $gzip);
            BackupCrypto::encryptFile(
                $gzip,
                $encrypted,
                BackupCrypto::keyFromBase64(Config::env('BACKUP_ENCRYPTION_KEY_BASE64', '') ?? '')
            );
            $bytes = filesize($encrypted);
            $hash = hash_file('sha256', $encrypted);
            if ($bytes === false || $bytes < 100 || $hash === false) {
                throw new RuntimeException('backup_validation_failed');
            }
            file_put_contents($manifest, json_encode([
                'format' => 'ssd-manager-backup-v1',
                'created_at' => gmdate(DATE_ATOM),
                'database' => Config::env('DB_DATABASE', 'ssd_manager'),
                'encrypted_file' => basename($encrypted),
                'encrypted_bytes' => $bytes,
                'sha256' => $hash,
            ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR) . "\n");
            $this->storage->upload($encrypted, basename($encrypted));
            $this->storage->upload($manifest, basename($manifest));
            $deleted = $this->storage->deleteExpired(max(7, Config::int('BACKUP_RETENTION_DAYS', 30)));
            $statement = $this->pdo->prepare(
                "UPDATE backup_runs SET status = 'succeeded', filename = :filename,
                 encrypted_bytes = :bytes, sha256 = :sha256, finished_at = UTC_TIMESTAMP() WHERE id = :id"
            );
            $statement->execute(['filename' => basename($encrypted), 'bytes' => $bytes, 'sha256' => $hash, 'id' => $runId]);
            return ['filename' => basename($encrypted), 'encrypted_bytes' => $bytes, 'sha256' => $hash, 'deleted_expired_files' => $deleted];
        } catch (\Throwable $exception) {
            $code = preg_match('/^[a-z0-9_]{3,80}$/', $exception->getMessage()) ? $exception->getMessage() : 'backup_failed';
            $statement = $this->pdo->prepare(
                "UPDATE backup_runs SET status = 'failed', error_code = :error, finished_at = UTC_TIMESTAMP() WHERE id = :id"
            );
            $statement->execute(['error' => $code, 'id' => $runId]);
            throw new RuntimeException($code, 0, $exception);
        } finally {
            foreach ([$sql, $gzip, $encrypted, $manifest] as $path) {
                if (is_file($path)) {
                    unlink($path);
                }
            }
            rmdir($directory);
        }
    }

    private function dumpDatabase(string $path): void
    {
        $command = [
            'mysqldump', '--single-transaction', '--quick', '--skip-lock-tables',
            '--default-character-set=utf8mb4',
            '--host=' . Config::env('DB_HOST', '127.0.0.1'),
            '--port=' . Config::env('DB_PORT', '3306'),
            '--user=' . Config::env('DB_USERNAME', 'root'),
            '--result-file=' . $path,
            Config::env('DB_DATABASE', 'ssd_manager'),
        ];
        $environment = array_merge(is_array(getenv()) ? getenv() : [], $_ENV, [
            'MYSQL_PWD' => Config::env('DB_PASSWORD', '') ?? '',
        ]);
        $process = proc_open($command, [['pipe', 'r'], ['pipe', 'w'], ['pipe', 'w']], $pipes, null, $environment);
        if (!is_resource($process)) {
            throw new RuntimeException('backup_dump_start_failed');
        }
        fclose($pipes[0]);
        stream_get_contents($pipes[1]);
        stream_get_contents($pipes[2]);
        fclose($pipes[1]);
        fclose($pipes[2]);
        if (proc_close($process) !== 0 || !is_file($path) || filesize($path) < 100) {
            throw new RuntimeException('backup_dump_failed');
        }
    }

    private function gzip(string $source, string $destination): void
    {
        $input = fopen($source, 'rb');
        $output = gzopen($destination, 'wb9');
        if ($input === false || $output === false) {
            throw new RuntimeException('backup_compression_failed');
        }
        try {
            while (!feof($input)) {
                $chunk = fread($input, 1048576);
                if ($chunk === false || gzwrite($output, $chunk) === false) {
                    throw new RuntimeException('backup_compression_failed');
                }
            }
        } finally {
            fclose($input);
            gzclose($output);
        }
    }

    private function assertConfigured(): void
    {
        foreach (['BACKUP_CRON_SECRET', 'BACKUP_ENCRYPTION_KEY_BASE64', 'BACKUP_FTP_HOST', 'BACKUP_FTP_USERNAME', 'BACKUP_FTP_PASSWORD'] as $key) {
            if (!Config::env($key)) {
                throw new RuntimeException('backup_not_configured');
            }
        }
    }
}
