<?php

declare(strict_types=1);

namespace App\Services;

use PDO;

final class AuditLogger
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    /**
     * @param array<string,mixed> $metadata
     */
    public function log(
        int $schoolId,
        int $actorUserId,
        string $action,
        ?int $targetUserId = null,
        ?string $targetType = null,
        ?int $targetId = null,
        array $metadata = [],
    ): void {
        $statement = $this->pdo->prepare(
            'INSERT INTO audit_logs
             (school_id, actor_user_id, action, target_user_id, target_type, target_id, metadata_json, created_at)
             VALUES (:school_id, :actor_user_id, :action, :target_user_id, :target_type, :target_id, :metadata_json, UTC_TIMESTAMP())'
        );
        $statement->execute([
            'school_id' => $schoolId,
            'actor_user_id' => $actorUserId,
            'action' => $action,
            'target_user_id' => $targetUserId,
            'target_type' => $targetType,
            'target_id' => $targetId,
            'metadata_json' => json_encode($metadata, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
        ]);
    }
}
