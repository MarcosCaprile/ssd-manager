<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Core\Request;
use App\Core\Response;
use App\Services\AnnouncementAttachmentService;
use App\Services\AnnouncementModerationService;
use App\Services\AuthContext;
use App\Services\NotificationService;
use App\Services\ObjectionableContentFilter;
use PDO;

final class AnnouncementController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly NotificationService $notifications,
        private readonly AnnouncementAttachmentService $attachments,
        private readonly AnnouncementModerationService $moderation,
    ) {
    }

    /**
     * @param array<string,string> $params
     */
    public function index(Request $request, array $params, AuthContext $auth): never
    {
        $statement = $this->pdo->prepare(
            'SELECT a.id, a.sender_user_id, a.message, a.message_type, a.system_type, a.created_at,
                    CASE WHEN a.moderated_at IS NULL THEN 0 ELSE 1 END AS is_moderated,
                    EXISTS(
                        SELECT 1 FROM announcement_reports ar
                        WHERE ar.announcement_id = a.id AND ar.reporter_user_id = :viewer_user_id
                    ) AS reported_by_me,
                    CONCAT(u.first_name, " ", u.last_name) AS sender_name, u.role AS sender_role
             FROM announcements a
             JOIN users u ON u.id = a.sender_user_id
             WHERE a.school_id = :school_id AND a.deleted_at IS NULL
             ORDER BY a.created_at DESC, a.id DESC
             LIMIT 100'
        );
        $statement->execute([
            'viewer_user_id' => $auth->userId(),
            'school_id' => $auth->schoolId(),
        ]);
        $rows = array_reverse($statement->fetchAll());
        $attachmentGroups = $this->attachments->groupedForAnnouncements(
            $auth->schoolId(),
            array_map(static fn (array $row): int => (int) $row['id'], $rows)
        );
        Response::json(array_map(fn (array $row): array => $this->serialize(
            $row,
            $attachmentGroups[(int) $row['id']] ?? []
        ), $rows));
    }

    /**
     * @param array<string,string> $params
     */
    public function uploadAttachment(Request $request, array $params, AuthContext $auth): never
    {
        Response::json(
            $this->attachments->upload($auth, $request->uploadedFile('attachment')),
            201
        );
    }

    /**
     * @param array<string,string> $params
     */
    public function downloadAttachment(Request $request, array $params, AuthContext $auth): never
    {
        $attachmentId = (int) ($params['id'] ?? 0);
        if ($attachmentId < 1) {
            Response::error('Anhang wurde nicht gefunden.', 404);
        }
        $attachment = $this->attachments->download($auth, $attachmentId);
        $fileName = (string) $attachment['file_name'];
        $asciiName = preg_replace('/[^A-Za-z0-9._-]/', '_', $fileName) ?: 'attachment';

        http_response_code(200);
        header('Content-Type: ' . $attachment['mime_type']);
        header('Content-Length: ' . (int) $attachment['size_bytes']);
        header(
            "Content-Disposition: inline; filename=\"{$asciiName}\"; filename*=UTF-8''" .
            rawurlencode($fileName)
        );
        header('Cache-Control: private, max-age=300');
        header('X-Content-Type-Options: nosniff');
        $content = $attachment['content'];
        if (is_resource($content)) {
            fpassthru($content);
        } else {
            echo (string) $content;
        }
        exit;
    }

    /**
     * @param array<string,string> $params
     */
    public function store(Request $request, array $params, AuthContext $auth): never
    {
        $data = $request->json();
        $message = trim(strip_tags((string) ($data['message'] ?? '')));
        $attachmentIds = $data['attachment_ids'] ?? [];
        if (!is_array($attachmentIds)) {
            Response::error('Ungültige Anhangsliste.', 422);
        }
        if (mb_strlen($message) > 2000) {
            Response::error('Nachrichten dürfen höchstens 2000 Zeichen haben.', 422);
        }
        if ($message === '' && $attachmentIds === []) {
            Response::error('Nachricht oder Anhang fehlt.', 422);
        }
        ObjectionableContentFilter::assertAllowed($message);

        $this->pdo->beginTransaction();
        try {
            $statement = $this->pdo->prepare(
                'INSERT INTO announcements (school_id, sender_user_id, message, created_at, updated_at)
                 VALUES (:school_id, :sender_user_id, :message, UTC_TIMESTAMP(), UTC_TIMESTAMP())'
            );
            $statement->execute([
                'school_id' => $auth->schoolId(),
                'sender_user_id' => $auth->userId(),
                'message' => $message,
            ]);
            $id = (int) $this->pdo->lastInsertId();
            $claimedAttachments = $this->attachments->claim(
                $auth,
                array_map('intval', $attachmentIds),
                $id
            );
            $this->pdo->commit();
        } catch (\Throwable $exception) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $exception;
        }

        try {
            $preview = $message === ''
                ? ' hat einen Anhang gesendet.'
                : ': ' . mb_substr($message, 0, 120);
            $this->notifications->notifyUsersByRole(
                $auth->schoolId(),
                ['sanitaeter', 'sani_leitung', 'teacher', 'sekretariat'],
                'announcement_created',
                'Neue Ankündigung',
                $auth->user['first_name'] . $preview,
                'announcement:' . $id,
                null,
                $id,
                [$auth->userId()],
                ['route' => 'announcements']
            );
        } catch (\Throwable $exception) {
            error_log('Announcement notification failed after successful save: ' . $exception->getMessage());
        }

        Response::json([
            'id' => $id,
            'sender_user_id' => $auth->userId(),
            'sender_name' => trim($auth->user['first_name'] . ' ' . $auth->user['last_name']),
            'sender_role' => $auth->role(),
            'message' => $message,
            'message_type' => 'user',
            'system_type' => null,
            'is_moderated' => false,
            'reported_by_me' => false,
            'created_at' => gmdate('Y-m-d H:i:s'),
            'attachments' => $claimedAttachments,
        ], 201);
    }

    /**
     * @param array<string,string> $params
     */
    public function report(Request $request, array $params, AuthContext $auth): never
    {
        $this->moderation->report($auth, (int) ($params['id'] ?? 0), $request->json());
        Response::json(['reported' => true], 201);
    }

    /**
     * @param array<string,string> $params
     */
    public function deleteOwn(Request $request, array $params, AuthContext $auth): never
    {
        $this->moderation->deleteOwn($auth, (int) ($params['id'] ?? 0));
        Response::json(['deleted' => true]);
    }

    /**
     * @param array<string,string> $params
     */
    public function reports(Request $request, array $params, AuthContext $auth): never
    {
        Response::json($this->moderation->list($auth));
    }

    /**
     * @param array<string,string> $params
     */
    public function moderateReport(Request $request, array $params, AuthContext $auth): never
    {
        $this->moderation->moderate($auth, (int) ($params['id'] ?? 0), $request->json());
        Response::json(['updated' => true]);
    }

    /**
     * @param array<string,mixed> $row
     * @param array<int,array<string,mixed>> $attachments
     * @return array<string,mixed>
     */
    private function serialize(array $row, array $attachments): array
    {
        return [
            'id' => (int) $row['id'],
            'sender_user_id' => (int) $row['sender_user_id'],
            'sender_name' => $row['sender_name'],
            'sender_role' => $row['sender_role'],
            'message' => $row['message'],
            'message_type' => $row['message_type'],
            'system_type' => $row['system_type'],
            'is_moderated' => (int) ($row['is_moderated'] ?? 0) === 1,
            'reported_by_me' => (int) ($row['reported_by_me'] ?? 0) === 1,
            'created_at' => $row['created_at'],
            'attachments' => $attachments,
        ];
    }
}
