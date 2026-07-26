<?php

declare(strict_types=1);

namespace App\Services;

use RuntimeException;

final class BackupCrypto
{
    private const MAGIC = "SSDMBK1\0";
    private const CHUNK_SIZE = 1048576;

    public static function keyFromBase64(string $encoded): string
    {
        $key = base64_decode($encoded, true);
        if ($key === false || strlen($key) !== SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_KEYBYTES) {
            throw new RuntimeException('backup_key_invalid');
        }
        return $key;
    }

    public static function encryptFile(string $source, string $destination, string $key): void
    {
        $input = fopen($source, 'rb');
        $output = fopen($destination, 'wb');
        if ($input === false || $output === false) {
            throw new RuntimeException('backup_file_open_failed');
        }
        try {
            [$state, $header] = sodium_crypto_secretstream_xchacha20poly1305_init_push($key);
            self::writeAll($output, self::MAGIC . $header);
            $finalWritten = false;
            while (!feof($input)) {
                $chunk = fread($input, self::CHUNK_SIZE);
                if ($chunk === false) {
                    throw new RuntimeException('backup_file_read_failed');
                }
                if ($chunk === '' && feof($input)) {
                    break;
                }
                $tag = feof($input)
                    ? SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_TAG_FINAL
                    : SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_TAG_MESSAGE;
                $ciphertext = sodium_crypto_secretstream_xchacha20poly1305_push($state, $chunk, '', $tag);
                self::writeAll($output, pack('N', strlen($ciphertext)) . $ciphertext);
                $finalWritten = $tag === SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_TAG_FINAL;
            }
            if (!$finalWritten) {
                $ciphertext = sodium_crypto_secretstream_xchacha20poly1305_push(
                    $state,
                    '',
                    '',
                    SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_TAG_FINAL
                );
                self::writeAll($output, pack('N', strlen($ciphertext)) . $ciphertext);
            }
        } finally {
            fclose($input);
            fclose($output);
        }
    }

    public static function decryptFile(string $source, string $destination, string $key): void
    {
        $input = fopen($source, 'rb');
        $output = fopen($destination, 'wb');
        if ($input === false || $output === false) {
            throw new RuntimeException('backup_file_open_failed');
        }
        try {
            if (fread($input, strlen(self::MAGIC)) !== self::MAGIC) {
                throw new RuntimeException('backup_format_invalid');
            }
            $header = fread($input, SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_HEADERBYTES);
            if ($header === false || strlen($header) !== SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_HEADERBYTES) {
                throw new RuntimeException('backup_format_invalid');
            }
            $state = sodium_crypto_secretstream_xchacha20poly1305_init_pull($header, $key);
            $final = false;
            while (!feof($input)) {
                $lengthBytes = fread($input, 4);
                if ($lengthBytes === '' && feof($input)) {
                    break;
                }
                if ($lengthBytes === false || strlen($lengthBytes) !== 4) {
                    throw new RuntimeException('backup_format_invalid');
                }
                $length = unpack('Nlength', $lengthBytes)['length'];
                $ciphertext = self::readExact($input, $length);
                $result = sodium_crypto_secretstream_xchacha20poly1305_pull($state, $ciphertext);
                if ($result === false) {
                    throw new RuntimeException('backup_authentication_failed');
                }
                [$plaintext, $tag] = $result;
                self::writeAll($output, $plaintext);
                $final = $tag === SODIUM_CRYPTO_SECRETSTREAM_XCHACHA20POLY1305_TAG_FINAL;
                if ($final && !feof($input)) {
                    $extra = fread($input, 1);
                    if ($extra !== '' && $extra !== false) {
                        throw new RuntimeException('backup_format_invalid');
                    }
                }
            }
            if (!$final) {
                throw new RuntimeException('backup_incomplete');
            }
        } finally {
            fclose($input);
            fclose($output);
        }
    }

    private static function readExact($stream, int $length): string
    {
        $data = '';
        while (strlen($data) < $length) {
            $chunk = fread($stream, $length - strlen($data));
            if ($chunk === false || $chunk === '') {
                throw new RuntimeException('backup_format_invalid');
            }
            $data .= $chunk;
        }
        return $data;
    }

    private static function writeAll($stream, string $data): void
    {
        $offset = 0;
        while ($offset < strlen($data)) {
            $written = fwrite($stream, substr($data, $offset));
            if ($written === false || $written === 0) {
                throw new RuntimeException('backup_file_write_failed');
            }
            $offset += $written;
        }
    }
}
