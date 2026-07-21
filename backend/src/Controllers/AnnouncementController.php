<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Core\Request;
use App\Core\Response;
use App\Services\AuthContext;
use App\Services\NotificationService;
use PDO;

final class AnnouncementController
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly NotificationService $notifications,
    ) {
    }

    /**
     * @param array<string,string> $params
     */
    public function index(Request $request, array $params, AuthContext $auth): never
    {
        $statement = $this->pdo->prepare(
            'SELECT a.id, a.sender_user_id, a.message, a.created_at,
                    CONCAT(u.first_name, " ", u.last_name) AS sender_name, u.role AS sender_role
             FROM announcements a
             JOIN users u ON u.id = a.sender_user_id
             WHERE a.school_id = :school_id AND a.deleted_at IS NULL
             ORDER BY a.created_at ASC
             LIMIT 100'
        );
        $statement->execute(['school_id' => $auth->schoolId()]);
        Response::json(array_map(fn (array $row) => [
            'id' => (int) $row['id'],
            'sender_user_id' => (int) $row['sender_user_id'],
            'sender_name' => $row['sender_name'],
            'sender_role' => $row['sender_role'],
            'message' => $row['message'],
            'created_at' => $row['created_at'],
        ], $statement->fetchAll()));
    }

    /**
     * @param array<string,string> $params
     */
    public function store(Request $request, array $params, AuthContext $auth): never
    {
        $data = $request->json();
        $message = trim(strip_tags((string) ($data['message'] ?? '')));
        if ($message === '' || mb_strlen($message) > 2000) {
            Response::error('Nachricht muss zwischen 1 und 2000 Zeichen haben.', 422);
        }
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
        $this->notifications->notifyUsersByRole(
            $auth->schoolId(),
            ['sanitaeter', 'sani_leitung', 'teacher'],
            'announcement_created',
            'Neue Ankündigung',
            $auth->user['first_name'] . ': ' . mb_substr($message, 0, 120),
            'announcement:' . $id,
            null,
            $id,
            [$auth->userId()],
            ['route' => 'announcements']
        );
        Response::json([
            'id' => $id,
            'sender_user_id' => $auth->userId(),
            'sender_name' => trim($auth->user['first_name'] . ' ' . $auth->user['last_name']),
            'sender_role' => $auth->role(),
            'message' => $message,
            'created_at' => gmdate('Y-m-d H:i:s'),
        ], 201);
    }
}
