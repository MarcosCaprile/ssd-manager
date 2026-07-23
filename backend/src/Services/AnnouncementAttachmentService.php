<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Response;
use PDO;

final class AnnouncementAttachmentService
{
    public const MAX_FILE_BYTES = 8 * 1024 * 1024;
    public const MAX_ATTACHMENTS_PER_ANNOUNCEMENT = 4;
    public const MAX_USER_STORAGE_BYTES = 100 * 1024 * 1024;

    /**
     * @var array<string,array<int,string>>
     */
    private const ALLOWED_TYPES = [
        'jpg' => ['image/jpeg'],
        'jpeg' => ['image/jpeg'],
        'png' => ['image/png'],
        'webp' => ['image/webp'],
        'heic' => ['image/heic', 'image/heif', 'application/octet-stream'],
        'heif' => ['image/heic', 'image/heif', 'application/octet-stream'],
        'pdf' => ['application/pdf'],
        'txt' => ['text/plain', 'application/x-empty'],
        'doc' => ['application/msword', 'application/x-ole-storage', 'application/octet-stream'],
        'docx' => [
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'application/zip',
            'application/octet-stream',
        ],
        'xls' => ['application/vnd.ms-excel', 'application/x-ole-storage', 'application/octet-stream'],
        'xlsx' => [
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/zip',
            'application/octet-stream',
        ],
        'ppt' => ['application/vnd.ms-powerpoint', 'application/x-ole-storage', 'application/octet-stream'],
        'pptx' => [
            'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'application/zip',
            'application/octet-stream',
        ],
    ];

    public function __construct(private readonly PDO $pdo)
    {
    }

    /**
     * @param array{name:string,tmp_name:string,size:int,error:int} $file
     * @return array<string,mixed>
     */
    public function upload(AuthContext $auth, array $file): array
    {
        $size = (int) filesize($file['tmp_name']);
        if ($size < 1 || $size > self::MAX_FILE_BYTES) {
            Response::error('Dateien müssen zwischen 1 Byte und 8 MB groß sein.', 413);
        }

        $fileName = $this->safeFileName($file['name']);
        $extension = strtolower((string) pathinfo($fileName, PATHINFO_EXTENSION));
        $mimeType = (new \finfo(FILEINFO_MIME_TYPE))->file($file['tmp_name']) ?: 'application/octet-stream';
        if (
            !array_key_exists($extension, self::ALLOWED_TYPES)
            || !in_array($mimeType, self::ALLOWED_TYPES[$extension], true)
        ) {
            Response::error(
                'Dieser Dateityp wird nicht unterstützt. Erlaubt sind Bilder, PDF, Text- und Office-Dateien.',
                422
            );
        }

        $content = file_get_contents($file['tmp_name']);
        if ($content === false || strlen($content) !== $size) {
            Response::error('Die Datei konnte nicht gelesen werden.', 422);
        }

        $this->pdo->beginTransaction();
        try {
            $lock = $this->pdo->prepare(
                'SELECT id FROM users WHERE id = :id AND school_id = :school_id FOR UPDATE'
            );
            $lock->execute(['id' => $auth->userId(), 'school_id' => $auth->schoolId()]);
            if (!$lock->fetchColumn()) {
                $this->rollbackAndError('Dein Account wurde nicht gefunden.', 404);
            }
            if ($this->usedBytes($auth) + $size > self::MAX_USER_STORAGE_BYTES) {
                $this->rollbackAndError(
                    'Dein Speicher ist voll. Lösche zuerst nicht mehr benötigte Dateien im Profil.',
                    413
                );
            }

            $statement = $this->pdo->prepare(
                'INSERT INTO announcement_attachments
                 (school_id, uploaded_by_user_id, announcement_id, file_name, mime_type, size_bytes, content, created_at)
                 VALUES (:school_id, :uploaded_by_user_id, NULL, :file_name, :mime_type, :size_bytes, :content, UTC_TIMESTAMP())'
            );
            $statement->bindValue(':school_id', $auth->schoolId(), PDO::PARAM_INT);
            $statement->bindValue(':uploaded_by_user_id', $auth->userId(), PDO::PARAM_INT);
            $statement->bindValue(':file_name', $fileName);
            $statement->bindValue(':mime_type', $mimeType);
            $statement->bindValue(':size_bytes', $size, PDO::PARAM_INT);
            $statement->bindValue(':content', $content, PDO::PARAM_LOB);
            $statement->execute();
            $id = (int) $this->pdo->lastInsertId();
            $this->pdo->commit();
        } catch (\Throwable $exception) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $exception;
        }

        return $this->metadata([
            'id' => $id,
            'file_name' => $fileName,
            'mime_type' => $mimeType,
            'size_bytes' => $size,
        ]);
    }

    /**
     * @param array<int,int> $attachmentIds
     * @return array<int,array<string,mixed>>
     */
    public function claim(
        AuthContext $auth,
        array $attachmentIds,
        int $announcementId,
    ): array {
        $attachmentIds = array_values(array_unique(array_filter(
            array_map('intval', $attachmentIds),
            static fn (int $id): bool => $id > 0
        )));
        if (count($attachmentIds) > self::MAX_ATTACHMENTS_PER_ANNOUNCEMENT) {
            $this->rollbackAndError('Pro Nachricht sind höchstens vier Anhänge möglich.');
        }
        if ($attachmentIds === []) {
            return [];
        }

        $placeholders = implode(',', array_fill(0, count($attachmentIds), '?'));
        $statement = $this->pdo->prepare(
            "SELECT id, file_name, mime_type, size_bytes
             FROM announcement_attachments
             WHERE id IN ({$placeholders}) AND school_id = ? AND uploaded_by_user_id = ?
               AND announcement_id IS NULL
             FOR UPDATE"
        );
        $statement->execute([
            ...$attachmentIds,
            $auth->schoolId(),
            $auth->userId(),
        ]);
        $rows = $statement->fetchAll();
        if (count($rows) !== count($attachmentIds)) {
            $this->rollbackAndError('Mindestens ein Anhang ist ungültig oder wurde bereits verwendet.');
        }

        $update = $this->pdo->prepare(
            "UPDATE announcement_attachments
             SET announcement_id = ?
             WHERE id IN ({$placeholders})"
        );
        $update->execute([$announcementId, ...$attachmentIds]);
        return array_map(fn (array $row): array => $this->metadata($row), $rows);
    }

    /**
     * @param array<int,int> $announcementIds
     * @return array<int,array<int,array<string,mixed>>>
     */
    public function groupedForAnnouncements(int $schoolId, array $announcementIds): array
    {
        if ($announcementIds === []) {
            return [];
        }
        $placeholders = implode(',', array_fill(0, count($announcementIds), '?'));
        $statement = $this->pdo->prepare(
            "SELECT id, announcement_id, file_name, mime_type, size_bytes
             FROM announcement_attachments
             WHERE school_id = ? AND announcement_id IN ({$placeholders})
             ORDER BY id ASC"
        );
        $statement->execute([$schoolId, ...$announcementIds]);
        $grouped = [];
        foreach ($statement->fetchAll() as $row) {
            $grouped[(int) $row['announcement_id']][] = $this->metadata($row);
        }
        return $grouped;
    }

    /**
     * @return array<string,mixed>
     */
    public function download(AuthContext $auth, int $attachmentId): array
    {
        $statement = $this->pdo->prepare(
            'SELECT aa.file_name, aa.mime_type, aa.size_bytes, aa.content
             FROM announcement_attachments aa
             JOIN announcements a ON a.id = aa.announcement_id
             WHERE aa.id = :id AND aa.school_id = :school_id
               AND a.school_id = :school_id_for_announcement AND a.deleted_at IS NULL
             LIMIT 1'
        );
        $statement->execute([
            'id' => $attachmentId,
            'school_id' => $auth->schoolId(),
            'school_id_for_announcement' => $auth->schoolId(),
        ]);
        $row = $statement->fetch();
        if (!$row) {
            Response::error('Anhang wurde nicht gefunden.', 404);
        }
        return $row;
    }

    public function deleteExpiredUnclaimed(): int
    {
        $statement = $this->pdo->prepare(
            'DELETE FROM announcement_attachments
             WHERE announcement_id IS NULL AND created_at < (UTC_TIMESTAMP() - INTERVAL 1 DAY)'
        );
        $statement->execute();
        return $statement->rowCount();
    }

    /**
     * @return array<string,mixed>
     */
    public function storageForUser(AuthContext $auth, string $sort): array
    {
        $orderBy = match ($sort) {
            'date_asc' => 'aa.created_at ASC, aa.id ASC',
            'size_desc' => 'aa.size_bytes DESC, aa.created_at DESC',
            'size_asc' => 'aa.size_bytes ASC, aa.created_at DESC',
            default => 'aa.created_at DESC, aa.id DESC',
        };
        $statement = $this->pdo->prepare(
            "SELECT aa.id, aa.announcement_id, aa.file_name, aa.mime_type, aa.size_bytes, aa.created_at
             FROM announcement_attachments aa
             LEFT JOIN announcements a ON a.id = aa.announcement_id
             WHERE aa.school_id = :school_id AND aa.uploaded_by_user_id = :user_id
               AND (aa.announcement_id IS NULL OR a.deleted_at IS NULL)
             ORDER BY {$orderBy}"
        );
        $statement->execute([
            'school_id' => $auth->schoolId(),
            'user_id' => $auth->userId(),
        ]);
        return [
            'used_bytes' => $this->usedBytes($auth),
            'limit_bytes' => self::MAX_USER_STORAGE_BYTES,
            'attachments' => array_map(function (array $row): array {
                return [
                    ...$this->metadata($row),
                    'announcement_id' => $row['announcement_id'] === null
                        ? null
                        : (int) $row['announcement_id'],
                    'created_at' => (string) $row['created_at'],
                ];
            }, $statement->fetchAll()),
        ];
    }

    public function deleteForUser(AuthContext $auth, int $attachmentId): void
    {
        if ($attachmentId < 1) {
            Response::error('Datei wurde nicht gefunden.', 404);
        }
        $this->pdo->beginTransaction();
        try {
            $statement = $this->pdo->prepare(
                'SELECT aa.id, aa.announcement_id, a.message
                 FROM announcement_attachments aa
                 LEFT JOIN announcements a ON a.id = aa.announcement_id
                 WHERE aa.id = :id AND aa.school_id = :school_id
                   AND aa.uploaded_by_user_id = :user_id
                   AND (aa.announcement_id IS NULL OR a.deleted_at IS NULL)
                 FOR UPDATE'
            );
            $statement->execute([
                'id' => $attachmentId,
                'school_id' => $auth->schoolId(),
                'user_id' => $auth->userId(),
            ]);
            $row = $statement->fetch();
            if (!$row) {
                if ($this->pdo->inTransaction()) {
                    $this->pdo->rollBack();
                }
                Response::error('Datei wurde nicht gefunden.', 404);
            }

            if ($row['announcement_id'] === null) {
                $this->pdo->prepare(
                    'DELETE FROM announcement_attachments WHERE id = :id'
                )->execute(['id' => $attachmentId]);
            } else {
                $count = $this->pdo->prepare(
                    'SELECT COUNT(*) FROM announcement_attachments WHERE announcement_id = :announcement_id'
                );
                $count->execute(['announcement_id' => $row['announcement_id']]);
                if (trim((string) $row['message']) === '' && (int) $count->fetchColumn() === 1) {
                    $this->pdo->prepare(
                        'DELETE FROM announcements WHERE id = :id AND school_id = :school_id'
                    )->execute([
                        'id' => $row['announcement_id'],
                        'school_id' => $auth->schoolId(),
                    ]);
                } else {
                    $this->pdo->prepare(
                        'DELETE FROM announcement_attachments WHERE id = :id'
                    )->execute(['id' => $attachmentId]);
                }
            }
            $this->pdo->commit();
        } catch (\Throwable $exception) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $exception;
        }
    }

    /**
     * @param array<string,mixed> $row
     * @return array<string,mixed>
     */
    private function metadata(array $row): array
    {
        $mimeType = (string) $row['mime_type'];
        return [
            'id' => (int) $row['id'],
            'file_name' => (string) $row['file_name'],
            'mime_type' => $mimeType,
            'size_bytes' => (int) $row['size_bytes'],
            'is_image' => in_array($mimeType, ['image/jpeg', 'image/png', 'image/webp'], true),
        ];
    }

    private function safeFileName(string $value): string
    {
        $name = trim(basename(str_replace('\\', '/', $value)));
        $name = preg_replace('/[\x00-\x1F\x7F]+/u', '', $name) ?? '';
        if ($name === '') {
            Response::error('Der Dateiname ist ungültig.', 422);
        }
        if (mb_strlen($name) > 180) {
            $extension = (string) pathinfo($name, PATHINFO_EXTENSION);
            $base = (string) pathinfo($name, PATHINFO_FILENAME);
            $suffix = $extension === '' ? '' : '.' . $extension;
            $name = mb_substr($base, 0, 180 - mb_strlen($suffix)) . $suffix;
        }
        return $name;
    }

    private function usedBytes(AuthContext $auth): int
    {
        $statement = $this->pdo->prepare(
            'SELECT COALESCE(SUM(size_bytes), 0)
             FROM announcement_attachments
             WHERE school_id = :school_id AND uploaded_by_user_id = :user_id'
        );
        $statement->execute([
            'school_id' => $auth->schoolId(),
            'user_id' => $auth->userId(),
        ]);
        return (int) $statement->fetchColumn();
    }

    private function rollbackAndError(string $message, int $status = 422): never
    {
        if ($this->pdo->inTransaction()) {
            $this->pdo->rollBack();
        }
        Response::error($message, $status);
    }
}
