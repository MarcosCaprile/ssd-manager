<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Config;
use RuntimeException;

final class FtpsBackupStorage
{
    public function upload(string $localPath, string $remoteName): void
    {
        $handle = fopen($localPath, 'rb');
        if ($handle === false) {
            throw new RuntimeException('backup_upload_open_failed');
        }
        $curl = $this->handle($remoteName);
        curl_setopt_array($curl, [
            CURLOPT_UPLOAD => true,
            CURLOPT_INFILE => $handle,
            CURLOPT_INFILESIZE => filesize($localPath),
            CURLOPT_FTP_CREATE_MISSING_DIRS => CURLFTP_CREATE_DIR_RETRY,
        ]);
        try {
            if (curl_exec($curl) !== true) {
                throw new RuntimeException('backup_upload_failed');
            }
            $status = curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
            if ($status >= 400) {
                throw new RuntimeException('backup_upload_failed');
            }
        } finally {
            curl_close($curl);
            fclose($handle);
        }
    }

    public function deleteExpired(int $retentionDays): int
    {
        $curl = $this->handle('');
        curl_setopt_array($curl, [CURLOPT_DIRLISTONLY => true, CURLOPT_RETURNTRANSFER => true]);
        try {
            $listing = curl_exec($curl);
            if (!is_string($listing)) {
                throw new RuntimeException('backup_listing_failed');
            }
        } finally {
            curl_close($curl);
        }
        $threshold = time() - ($retentionDays * 86400);
        $deleted = 0;
        foreach (preg_split('/\r?\n/', trim($listing)) ?: [] as $name) {
            if (!preg_match('/^ssd-manager-(\d{8}T\d{6}Z)\.(sql\.gz\.enc|manifest\.json)$/', $name, $match)) {
                continue;
            }
            $created = \DateTimeImmutable::createFromFormat('!Ymd\\THis\\Z', $match[1], new \DateTimeZone('UTC'));
            if ($created === false || $created->getTimestamp() >= $threshold) {
                continue;
            }
            $delete = $this->handle('');
            curl_setopt($delete, CURLOPT_QUOTE, ['DELE ' . $this->remotePath($name)]);
            try {
                if (curl_exec($delete) !== true) {
                    throw new RuntimeException('backup_retention_failed');
                }
            } finally {
                curl_close($delete);
            }
            $deleted++;
        }
        return $deleted;
    }

    private function handle(string $name): \CurlHandle
    {
        $host = Config::env('BACKUP_FTP_HOST');
        $user = Config::env('BACKUP_FTP_USERNAME');
        $password = Config::env('BACKUP_FTP_PASSWORD');
        if (!$host || !$user || !$password) {
            throw new RuntimeException('backup_storage_not_configured');
        }
        $url = 'ftp://' . $host . ':' . Config::int('BACKUP_FTP_PORT', 21) . $this->remotePath($name);
        $curl = curl_init($url);
        curl_setopt_array($curl, [
            CURLOPT_USERPWD => $user . ':' . $password,
            CURLOPT_USE_SSL => CURLUSESSL_ALL,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_FTPSSLAUTH => CURLFTPAUTH_TLS,
            CURLOPT_CONNECTTIMEOUT => 20,
            CURLOPT_TIMEOUT => 300,
        ]);
        return $curl;
    }

    private function remotePath(string $name): string
    {
        $directory = trim(Config::env('BACKUP_FTP_REMOTE_DIRECTORY', '/') ?? '/', '/');
        return '/' . ($directory === '' ? '' : $directory . '/') . rawurlencode($name);
    }
}
