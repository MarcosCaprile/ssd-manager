<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Core\Config;
use App\Services\BackupCrypto;

[$script, $source, $destination] = array_pad($argv, 3, null);
if (!$source || !$destination || !is_file($source)) {
    fwrite(STDERR, "Usage: php backend/scripts/decrypt_backup.php BACKUP.sql.gz.enc OUTPUT.sql.gz\n");
    exit(1);
}
BackupCrypto::decryptFile(
    $source,
    $destination,
    BackupCrypto::keyFromBase64(Config::env('BACKUP_ENCRYPTION_KEY_BASE64', '') ?? '')
);
echo "Backup authenticated and decrypted.\n";
