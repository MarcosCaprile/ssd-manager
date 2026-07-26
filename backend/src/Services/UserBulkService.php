<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Response;
use PDO;

final class UserBulkService
{
    private AuditLogger $audit;

    public function __construct(private readonly PDO $pdo)
    {
        $this->audit = new AuditLogger($pdo);
    }

    /**
     * @param array<int,mixed> $rows
     * @return array{valid:bool,rows:array<int,array<string,mixed>>}
     */
    public function validate(AuthContext $auth, array $rows): array
    {
        $analysis = $this->analyze($auth, $rows);
        return [
            'valid' => $analysis['valid'],
            'rows' => $analysis['rows'],
        ];
    }

    /**
     * @param array<int,mixed> $rows
     * @return array{valid:bool,applied:bool,applied_count:int,rows:array<int,array<string,mixed>>}
     */
    public function apply(AuthContext $auth, array $rows): array
    {
        $analysis = $this->analyze($auth, $rows);
        if (!$analysis['valid']) {
            return [
                'valid' => false,
                'applied' => false,
                'applied_count' => 0,
                'rows' => $analysis['rows'],
            ];
        }

        $this->pdo->beginTransaction();
        try {
            foreach ($analysis['normalized'] as $row) {
                $this->applyRow($auth, $row);
            }
            $this->pdo->commit();
        } catch (\Throwable $exception) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            if ($exception instanceof \PDOException
                && ($exception->getCode() === '23000' || (int) ($exception->errorInfo[1] ?? 0) === 1062)
            ) {
                Response::error(
                    'Die Bulk-Datei konnte nicht angewendet werden, weil Benutzername oder E-Mail inzwischen vergeben ist. Bitte prüfe die Datei erneut.',
                    409
                );
            }
            throw $exception;
        }

        return [
            'valid' => true,
            'applied' => true,
            'applied_count' => count($analysis['normalized']),
            'rows' => $analysis['rows'],
        ];
    }

    /**
     * @param array<int,mixed> $inputRows
     * @return array{
     *   valid:bool,
     *   rows:array<int,array<string,mixed>>,
     *   normalized:array<int,array<string,mixed>>
     * }
     */
    private function analyze(AuthContext $auth, array $inputRows): array
    {
        if (!$auth->canManageUsers()) {
            Response::error('Du darfst keine Accounts verwalten.', 403);
        }
        if ($inputRows === [] || count($inputRows) > 250) {
            Response::error('Eine Bulk-Datei muss zwischen 1 und 250 Aktionen enthalten.', 422);
        }

        $statement = $this->pdo->prepare(
            'SELECT * FROM users WHERE school_id = :school_id AND deleted_at IS NULL ORDER BY id'
        );
        $statement->execute(['school_id' => $auth->schoolId()]);
        $users = $statement->fetchAll();

        $byId = [];
        $usernameOwners = [];
        $emailOwners = [];
        foreach ($users as $user) {
            $id = (int) $user['id'];
            $byId[$id] = $user;
            $usernameOwners[mb_strtolower((string) $user['username'])] = $id;
            $emailOwners[mb_strtolower((string) $user['email'])] = $id;
        }

        $resultRows = [];
        $normalizedRows = [];
        $allValid = true;

        foreach ($inputRows as $index => $raw) {
            $rowNumber = is_array($raw) && isset($raw['row_number'])
                ? max(1, (int) $raw['row_number'])
                : $index + 1;
            $errors = [];
            if (!is_array($raw)) {
                $errors[] = 'Die Zeile hat kein gültiges Mapping.';
                $resultRows[] = $this->publicResult($rowNumber, '', null, '', $errors);
                $allValid = false;
                continue;
            }

            $action = trim((string) ($raw['action'] ?? ''));
            if (!in_array($action, ['create', 'update', 'deactivate', 'reactivate', 'mark_deletion'], true)) {
                $errors[] = 'Die Aktion ist ungültig.';
            }

            $targetId = $this->positiveInt($raw['id'] ?? null);
            $firstName = $this->cleanText($raw['first_name'] ?? null);
            $lastName = $this->cleanText($raw['last_name'] ?? null);
            $username = $this->cleanText($raw['username'] ?? null);
            $email = mb_strtolower($this->cleanText($raw['email'] ?? null));
            $password = (string) ($raw['temporary_password'] ?? '');
            $role = trim((string) ($raw['role'] ?? ''));
            $sanitaeterSince = trim((string) ($raw['sanitaeter_since'] ?? ''));
            $target = $targetId === null ? null : ($byId[$targetId] ?? null);

            if ($action === 'create') {
                if ($targetId !== null) {
                    $errors[] = 'Beim Hinzufügen muss die ID leer bleiben.';
                }
                $this->validateEditableFields(
                    $firstName,
                    $lastName,
                    $username,
                    $email,
                    $role,
                    $errors
                );
                if (mb_strlen($password) < 10 || mb_strlen($password) > 255) {
                    $errors[] = 'Das temporäre Passwort muss 10–255 Zeichen haben.';
                }
                $this->validateSanitaeterSince($sanitaeterSince, $errors);
                if ($auth->role() === 'sani_leitung' && $role !== 'sanitaeter') {
                    $errors[] = 'Die Sani-Leitung darf neue Accounts nur als Schulsanitäter anlegen.';
                }
                $this->validateUniqueOwner($usernameOwners, $username, null, 'Benutzername', $errors);
                $this->validateUniqueOwner($emailOwners, $email, null, 'E-Mail', $errors);
                if ($errors === []) {
                    $temporaryOwner = -($index + 1);
                    $usernameOwners[mb_strtolower($username)] = $temporaryOwner;
                    $emailOwners[$email] = $temporaryOwner;
                }
            } elseif (in_array($action, ['update', 'deactivate', 'reactivate', 'mark_deletion'], true)) {
                if ($targetId === null || $target === null) {
                    $errors[] = 'Die exportierte Account-ID fehlt oder gehört nicht zu dieser Schule.';
                } elseif ($targetId === $auth->userId()) {
                    $errors[] = 'Der eigene Account kann nicht per Bulk verwaltet werden.';
                } elseif (!in_array((string) $target['role'], ['sanitaeter', 'sani_leitung'], true)) {
                    $errors[] = 'Bulk-Aktionen sind nur für Sani- und Leitungsaccounts zulässig.';
                }

                if ($action === 'update' && $target !== null) {
                    $this->validateEditableFields(
                        $firstName,
                        $lastName,
                        $username,
                        $email,
                        $role,
                        $errors
                    );
                    $this->validateUniqueOwner($usernameOwners, $username, $targetId, 'Benutzername', $errors);
                    $this->validateUniqueOwner($emailOwners, $email, $targetId, 'E-Mail', $errors);
                    if ($errors === []) {
                        unset($usernameOwners[mb_strtolower((string) $target['username'])]);
                        unset($emailOwners[mb_strtolower((string) $target['email'])]);
                        $usernameOwners[mb_strtolower($username)] = $targetId;
                        $emailOwners[$email] = $targetId;
                        $byId[$targetId]['first_name'] = $firstName;
                        $byId[$targetId]['last_name'] = $lastName;
                        $byId[$targetId]['username'] = $username;
                        $byId[$targetId]['email'] = $email;
                        $byId[$targetId]['role'] = $role;
                    }
                }

                if ($target !== null && $action === 'deactivate' && $target['status'] !== 'active') {
                    $errors[] = 'Der Account ist nicht aktiv.';
                }
                if ($target !== null && $action === 'reactivate' && $target['status'] !== 'inactive') {
                    $errors[] = 'Nur deaktivierte Accounts können reaktiviert werden.';
                }
                if ($target !== null && $action === 'mark_deletion' && $target['status'] === 'pending_deletion') {
                    $errors[] = 'Der Account ist bereits zur Löschung vorgemerkt.';
                }
            }

            $displayName = trim($firstName . ' ' . $lastName);
            if ($displayName === '' && $target !== null) {
                $displayName = trim((string) $target['first_name'] . ' ' . (string) $target['last_name']);
            }
            $resultRows[] = $this->publicResult($rowNumber, $action, $targetId, $displayName, $errors);
            if ($errors !== []) {
                $allValid = false;
                continue;
            }
            $normalizedRows[] = [
                'row_number' => $rowNumber,
                'action' => $action,
                'id' => $targetId,
                'first_name' => $firstName,
                'last_name' => $lastName,
                'username' => $username,
                'email' => $email,
                'temporary_password' => $password,
                'role' => $role,
                'sanitaeter_since' => $sanitaeterSince,
            ];
        }

        return [
            'valid' => $allValid,
            'rows' => $resultRows,
            'normalized' => $normalizedRows,
        ];
    }

    /**
     * @param array<string,mixed> $row
     */
    private function applyRow(AuthContext $auth, array $row): void
    {
        $action = (string) $row['action'];
        $targetId = $row['id'] === null ? null : (int) $row['id'];

        if ($action === 'create') {
            $statement = $this->pdo->prepare(
                'INSERT INTO users
                 (school_id, first_name, last_name, username, email, password_hash, role, sanitaeter_since,
                  status, must_change_password, created_at, updated_at)
                 VALUES
                 (:school_id, :first_name, :last_name, :username, :email, :password_hash, :role, :sanitaeter_since,
                  "active", 1, UTC_TIMESTAMP(), UTC_TIMESTAMP())'
            );
            $statement->execute([
                'school_id' => $auth->schoolId(),
                'first_name' => $row['first_name'],
                'last_name' => $row['last_name'],
                'username' => $row['username'],
                'email' => $row['email'],
                'password_hash' => PasswordHasher::hash((string) $row['temporary_password']),
                'role' => $row['role'],
                'sanitaeter_since' => $row['sanitaeter_since'],
            ]);
            $newId = (int) $this->pdo->lastInsertId();
            $this->audit->log($auth->schoolId(), $auth->userId(), 'user.bulk_created', $newId, 'user', null, [
                'row_number' => $row['row_number'],
            ]);
            return;
        }

        if ($action === 'update' && $targetId !== null) {
            $this->pdo->prepare(
                'UPDATE users
                 SET first_name = :first_name, last_name = :last_name, username = :username,
                     email = :email, role = :role, updated_at = UTC_TIMESTAMP()
                 WHERE id = :id AND school_id = :school_id'
            )->execute([
                'first_name' => $row['first_name'],
                'last_name' => $row['last_name'],
                'username' => $row['username'],
                'email' => $row['email'],
                'role' => $row['role'],
                'id' => $targetId,
                'school_id' => $auth->schoolId(),
            ]);
            $this->audit->log($auth->schoolId(), $auth->userId(), 'user.bulk_updated', $targetId, 'user', null, [
                'row_number' => $row['row_number'],
                'role' => $row['role'],
            ]);
            return;
        }

        $status = match ($action) {
            'deactivate' => 'inactive',
            'reactivate' => 'active',
            'mark_deletion' => 'pending_deletion',
            default => null,
        };
        if ($status === null || $targetId === null) {
            return;
        }
        if ($action === 'mark_deletion') {
            $this->pdo->prepare(
                'UPDATE users
                 SET status = "pending_deletion",
                     permanent_deletion_due_at = UTC_TIMESTAMP() + INTERVAL 30 DAY,
                     updated_at = UTC_TIMESTAMP()
                 WHERE id = :id AND school_id = :school_id'
            )->execute(['id' => $targetId, 'school_id' => $auth->schoolId()]);
        } else {
            $this->pdo->prepare(
                'UPDATE users
                 SET status = :status,
                     deactivated_at = CASE WHEN :status_for_date = "inactive" THEN UTC_TIMESTAMP() ELSE NULL END,
                     permanent_deletion_due_at = NULL,
                     updated_at = UTC_TIMESTAMP()
                 WHERE id = :id AND school_id = :school_id'
            )->execute([
                'status' => $status,
                'status_for_date' => $status,
                'id' => $targetId,
                'school_id' => $auth->schoolId(),
            ]);
        }
        if ($action !== 'reactivate') {
            $this->pdo->prepare(
                'UPDATE user_devices
                 SET revoked_at = UTC_TIMESTAMP(), firebase_token = NULL
                 WHERE user_id = :user_id AND revoked_at IS NULL'
            )->execute(['user_id' => $targetId]);
        }
        $this->audit->log(
            $auth->schoolId(),
            $auth->userId(),
            'user.bulk_' . $action,
            $targetId,
            'user',
            null,
            ['row_number' => $row['row_number']]
        );
    }

    /**
     * @param array<int,string> $errors
     */
    private function validateEditableFields(
        string $firstName,
        string $lastName,
        string $username,
        string $email,
        string $role,
        array &$errors,
    ): void {
        foreach ([
            'Vorname' => $firstName,
            'Nachname' => $lastName,
            'Benutzername' => $username,
        ] as $label => $value) {
            if (mb_strlen($value) < 1 || mb_strlen($value) > 120) {
                $errors[] = "{$label} muss 1–120 Zeichen haben.";
            }
        }
        if (mb_strlen($email) > 180 || filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
            $errors[] = 'Die E-Mail-Adresse ist ungültig.';
        }
        if (!in_array($role, ['sanitaeter', 'sani_leitung'], true)) {
            $errors[] = 'Die Rolle muss sanitaeter oder sani_leitung sein.';
        }
    }

    /**
     * @param array<int,string> $errors
     */
    private function validateSanitaeterSince(string $value, array &$errors): void
    {
        $date = \DateTimeImmutable::createFromFormat('!Y-m-d', $value);
        $dateErrors = \DateTimeImmutable::getLastErrors();
        if (
            $date === false
            || ($dateErrors !== false && ($dateErrors['warning_count'] > 0 || $dateErrors['error_count'] > 0))
            || $date->format('Y-m-d') !== $value
        ) {
            $errors[] = '„Sanitäter seit“ muss ein gültiges Datum im Format YYYY-MM-DD sein.';
        }
    }

    /**
     * @param array<string,int> $owners
     * @param array<int,string> $errors
     */
    private function validateUniqueOwner(
        array $owners,
        string $value,
        ?int $allowedOwner,
        string $label,
        array &$errors,
    ): void {
        $key = mb_strtolower($value);
        if ($key === '') {
            return;
        }
        $owner = $owners[$key] ?? null;
        if ($owner !== null && $owner !== $allowedOwner) {
            $errors[] = "{$label} ist bereits vergeben oder kommt mehrfach in der Datei vor.";
        }
    }

    private function cleanText(mixed $value): string
    {
        return trim(strip_tags((string) ($value ?? '')));
    }

    private function positiveInt(mixed $value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }
        $number = filter_var($value, FILTER_VALIDATE_INT);
        return $number === false || $number < 1 ? null : (int) $number;
    }

    /**
     * @param array<int,string> $errors
     * @return array<string,mixed>
     */
    private function publicResult(
        int $rowNumber,
        string $action,
        ?int $targetId,
        string $displayName,
        array $errors,
    ): array {
        return [
            'row_number' => $rowNumber,
            'action' => $action,
            'target_user_id' => $targetId,
            'display_name' => $displayName,
            'valid' => $errors === [],
            'errors' => $errors,
        ];
    }
}
