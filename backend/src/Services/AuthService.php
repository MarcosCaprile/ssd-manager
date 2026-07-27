<?php

declare(strict_types=1);

namespace App\Services;

use App\Core\Config;
use App\Core\Request;
use App\Core\Response;
use PDO;

final class AuthService
{
    private TokenService $tokens;

    public function __construct(
        private readonly PDO $pdo,
        private readonly RateLimiter $rateLimiter,
    ) {
        $this->tokens = new TokenService();
    }

    /**
     * @param array<string,mixed> $input
     * @return array<string,mixed>
     */
    public function login(array $input, string $ip): array
    {
        $identifier = mb_strtolower(trim((string) ($input['identifier'] ?? '')));
        $password = (string) ($input['password'] ?? '');
        if ($identifier === '' || $password === '') {
            Response::error('Bitte gib deine E-Mail-Adresse oder deinen Benutzernamen und dein Passwort ein.', 422);
        }
        if ($this->rateLimiter->tooManyLoginAttempts($identifier, $ip)) {
            Response::error('Zu viele fehlgeschlagene Anmeldeversuche. Bitte später erneut versuchen.', 429);
        }

        $statement = $this->pdo->prepare(
            'SELECT u.* FROM users u
             JOIN schools s ON s.id = u.school_id
             WHERE (LOWER(u.email) = :email_identifier OR LOWER(u.username) = :username_identifier)
               AND u.deleted_at IS NULL
               AND s.active = 1'
        );
        $statement->execute([
            'email_identifier' => $identifier,
            'username_identifier' => $identifier,
        ]);
        $passwordMatches = array_values(array_filter(
            $statement->fetchAll(),
            static fn (array $candidate): bool => password_verify(
                $password,
                (string) $candidate['password_hash']
            )
        ));
        $user = count($passwordMatches) === 1 ? $passwordMatches[0] : null;
        if ($user === null) {
            $this->rateLimiter->recordLogin($identifier, $ip, false);
            Response::error('E-Mail/Benutzername oder Passwort ist nicht korrekt.', 401);
        }
        if ($user['status'] !== 'active') {
            $this->rateLimiter->recordLogin($identifier, $ip, false);
            if ($user['status'] === 'inactive') {
                Response::error(
                    'Dieser Account wurde deaktiviert. Bitte wende dich an eine verantwortliche Person deiner Schule.',
                    403
                );
            }
            Response::error(
                'Dieser Account kann derzeit nicht verwendet werden. Bitte wende dich an eine verantwortliche Person deiner Schule.',
                403
            );
        }

        $this->rateLimiter->recordLogin($identifier, $ip, true);
        return $this->createDeviceSession($user, $input);
    }

    /**
     * @param array<string,mixed> $input
     * @return array<string,mixed>
     */
    public function refresh(array $input): array
    {
        $refreshToken = (string) ($input['refresh_token'] ?? '');
        if ($refreshToken === '') {
            Response::error('Sitzung ist ungültig.', 401);
        }
        $hash = hash('sha256', $refreshToken);
        $statement = $this->pdo->prepare(
            'SELECT d.*, u.id AS u_id, u.school_id, u.first_name, u.last_name, u.username, u.email,
                    u.password_hash, u.role, u.sanitaeter_since, u.status, u.must_change_password
             FROM user_devices d
             JOIN users u ON u.id = d.user_id
             WHERE d.refresh_token_hash = :hash
               AND d.revoked_at IS NULL
               AND d.expires_at > UTC_TIMESTAMP()
               AND u.deleted_at IS NULL
             LIMIT 1'
        );
        $statement->execute(['hash' => $hash]);
        $row = $statement->fetch();
        if (!$row || $row['status'] !== 'active') {
            Response::error('Sitzung ist abgelaufen.', 401);
        }

        $refresh = bin2hex(random_bytes(32));
        $update = $this->pdo->prepare(
            'UPDATE user_devices
             SET refresh_token_hash = :hash, last_active_at = UTC_TIMESTAMP()
             WHERE id = :id'
        );
        $update->execute([
            'hash' => hash('sha256', $refresh),
            'id' => $row['id'],
        ]);

        $user = $this->userFromDeviceRow($row);
        return [
            'access_token' => $this->accessToken($user, (int) $row['id']),
            'refresh_token' => $refresh,
            'user' => $this->publicUser($user),
        ];
    }

    public function requireAuth(Request $request): AuthContext
    {
        $token = $request->bearerToken();
        if (!$token) {
            Response::error('Authentifizierung erforderlich.', 401);
        }
        $payload = $this->tokens->verify($token);
        if (!$payload) {
            Response::error('Sitzung ist abgelaufen.', 401);
        }
        $statement = $this->pdo->prepare(
            'SELECT d.id AS device_id, d.user_id AS device_user_id, d.refresh_token_hash, d.device_name,
                    d.platform, d.device_model, d.app_version, d.firebase_token, d.created_at AS device_created_at,
                    d.last_active_at, d.revoked_at, d.expires_at,
                    u.id AS user_id, u.school_id, u.first_name, u.last_name, u.username, u.email,
                    u.password_hash, u.role, u.sanitaeter_since, u.status, u.must_change_password
             FROM user_devices d
             JOIN users u ON u.id = d.user_id
             WHERE d.id = :device_id AND u.id = :user_id
               AND d.revoked_at IS NULL AND d.expires_at > UTC_TIMESTAMP()
               AND u.status = "active" AND u.deleted_at IS NULL
             LIMIT 1'
        );
        $statement->execute([
            'device_id' => (int) $payload['session_id'],
            'user_id' => (int) $payload['sub'],
        ]);
        $row = $statement->fetch();
        if (!$row) {
            Response::error('Sitzung ist nicht mehr gültig.', 401);
        }
        $this->pdo->prepare('UPDATE user_devices SET last_active_at = UTC_TIMESTAMP() WHERE id = :id')
            ->execute(['id' => $row['device_id']]);
        $row['id'] = (int) $row['device_id'];
        return new AuthContext($this->userFromJoinedRow($row), $row);
    }

    public function logout(AuthContext $auth): void
    {
        $this->pdo->prepare(
            'UPDATE user_devices SET revoked_at = UTC_TIMESTAMP(), firebase_token = NULL WHERE id = :id'
        )->execute(['id' => $auth->deviceId()]);
    }

    public function updateFirebaseToken(AuthContext $auth, ?string $token): void
    {
        $this->pdo->prepare(
            'UPDATE user_devices SET firebase_token = :token, last_active_at = UTC_TIMESTAMP() WHERE id = :id'
        )->execute([
            'token' => $token,
            'id' => $auth->deviceId(),
        ]);
    }

    /**
     * @param array<string,mixed> $input
     * @return array<string,mixed>
     */
    public function changePassword(AuthContext $auth, array $input): array
    {
        $current = (string) ($input['current_password'] ?? '');
        $new = (string) ($input['new_password'] ?? '');
        if (mb_strlen($new) < 10) {
            Response::error('Das neue Passwort muss mindestens 10 Zeichen haben.', 422);
        }
        $statement = $this->pdo->prepare('SELECT * FROM users WHERE id = :id LIMIT 1');
        $statement->execute(['id' => $auth->userId()]);
        $user = $statement->fetch();
        if (!$user || !password_verify($current, (string) $user['password_hash'])) {
            Response::error('Das aktuelle Passwort ist nicht korrekt.', 422);
        }

        $this->pdo->prepare(
            'UPDATE users
             SET password_hash = :hash, must_change_password = 0, updated_at = UTC_TIMESTAMP()
             WHERE id = :id'
        )->execute([
            'hash' => PasswordHasher::hash($new),
            'id' => $auth->userId(),
        ]);

        if (($input['revoke_other_devices'] ?? false) === true) {
            $this->revokeOtherDevices($auth);
        }

        $statement->execute(['id' => $auth->userId()]);
        return $this->publicUser($statement->fetch());
    }

    public function revokeOtherDevices(AuthContext $auth): void
    {
        $this->pdo->prepare(
            'UPDATE user_devices
             SET revoked_at = UTC_TIMESTAMP(), firebase_token = NULL
             WHERE user_id = :user_id AND id <> :device_id AND revoked_at IS NULL'
        )->execute([
            'user_id' => $auth->userId(),
            'device_id' => $auth->deviceId(),
        ]);
    }

    public function revokeDevice(AuthContext $auth, int $deviceId): void
    {
        $this->pdo->prepare(
            'UPDATE user_devices
             SET revoked_at = UTC_TIMESTAMP(), firebase_token = NULL
             WHERE user_id = :user_id AND id = :device_id AND id <> :current_id'
        )->execute([
            'user_id' => $auth->userId(),
            'device_id' => $deviceId,
            'current_id' => $auth->deviceId(),
        ]);
    }

    /**
     * @param array<string,mixed> $user
     * @param array<string,mixed> $input
     * @return array<string,mixed>
     */
    private function createDeviceSession(array $user, array $input): array
    {
        $refresh = bin2hex(random_bytes(32));
        $ttlDays = Config::int('REFRESH_TOKEN_TTL_DAYS', 90);
        $deviceName = mb_substr((string) ($input['device_name'] ?? 'Unbekanntes Gerät'), 0, 120);
        $platform = mb_substr((string) ($input['platform'] ?? 'unknown'), 0, 32);
        $deviceModel = mb_substr((string) ($input['device_model'] ?? ''), 0, 120);
        $appVersion = mb_substr((string) ($input['app_version'] ?? ''), 0, 40);
        $installId = trim((string) ($input['device_install_id'] ?? ''));
        if ($installId !== '' && !preg_match('/^[A-Za-z0-9_-]{16,64}$/', $installId)) {
            Response::error('Die Gerätekennung ist ungültig.', 422);
        }

        if ($installId !== '') {
            $this->pdo->prepare(
                'UPDATE user_devices
                 SET revoked_at = UTC_TIMESTAMP(), firebase_token = NULL
                 WHERE user_id = :user_id AND revoked_at IS NULL
                   AND device_install_id = :device_install_id'
            )->execute([
                'user_id' => (int) $user['id'],
                'device_install_id' => $installId,
            ]);
        }

        $statement = $this->pdo->prepare(
            'INSERT INTO user_devices
             (user_id, device_install_id, refresh_token_hash, device_name, platform, device_model, app_version, firebase_token,
              created_at, last_active_at, expires_at)
             VALUES
             (:user_id, :device_install_id, :refresh_hash, :device_name, :platform, :device_model, :app_version, :firebase_token,
              UTC_TIMESTAMP(), UTC_TIMESTAMP(), UTC_TIMESTAMP() + INTERVAL :ttl DAY)'
        );
        $statement->bindValue(':user_id', (int) $user['id'], PDO::PARAM_INT);
        $statement->bindValue(
            ':device_install_id',
            $installId === '' ? null : $installId,
            $installId === '' ? PDO::PARAM_NULL : PDO::PARAM_STR
        );
        $statement->bindValue(':refresh_hash', hash('sha256', $refresh));
        $statement->bindValue(':device_name', $deviceName);
        $statement->bindValue(':platform', $platform);
        $statement->bindValue(':device_model', $deviceModel);
        $statement->bindValue(':app_version', $appVersion);
        $statement->bindValue(':firebase_token', $input['firebase_token'] ?? null);
        $statement->bindValue(':ttl', $ttlDays, PDO::PARAM_INT);
        $statement->execute();
        $deviceId = (int) $this->pdo->lastInsertId();

        return [
            'access_token' => $this->accessToken($user, $deviceId),
            'refresh_token' => $refresh,
            'user' => $this->publicUser($user),
        ];
    }

    /**
     * @param array<string,mixed> $user
     */
    private function accessToken(array $user, int $deviceId): string
    {
        return $this->tokens->issue([
            'sub' => (int) $user['id'],
            'school_id' => (int) $user['school_id'],
            'role' => (string) $user['role'],
            'session_id' => $deviceId,
        ], Config::int('ACCESS_TOKEN_TTL_SECONDS', 900));
    }

    /**
     * @param array<string,mixed> $user
     * @return array<string,mixed>
     */
    public function publicUser(array $user): array
    {
        return [
            'id' => (int) $user['id'],
            'school_id' => (int) $user['school_id'],
            'first_name' => (string) $user['first_name'],
            'last_name' => (string) $user['last_name'],
            'username' => (string) $user['username'],
            'email' => (string) $user['email'],
            'role' => (string) $user['role'],
            'sanitaeter_since' => $user['sanitaeter_since'] ?? null,
            'status' => (string) $user['status'],
            'must_change_password' => (bool) $user['must_change_password'],
        ];
    }

    /**
     * @param array<string,mixed> $row
     * @return array<string,mixed>
     */
    private function userFromDeviceRow(array $row): array
    {
        return [
            'id' => (int) $row['user_id'],
            'school_id' => (int) $row['school_id'],
            'first_name' => (string) $row['first_name'],
            'last_name' => (string) $row['last_name'],
            'username' => (string) $row['username'],
            'email' => (string) $row['email'],
            'role' => (string) $row['role'],
            'sanitaeter_since' => $row['sanitaeter_since'] ?? null,
            'status' => (string) $row['status'],
            'must_change_password' => (bool) $row['must_change_password'],
        ];
    }

    /**
     * @param array<string,mixed> $row
     * @return array<string,mixed>
     */
    private function userFromJoinedRow(array $row): array
    {
        return [
            'id' => (int) $row['user_id'],
            'school_id' => (int) $row['school_id'],
            'first_name' => (string) $row['first_name'],
            'last_name' => (string) $row['last_name'],
            'username' => (string) $row['username'],
            'email' => (string) $row['email'],
            'role' => (string) $row['role'],
            'sanitaeter_since' => $row['sanitaeter_since'] ?? null,
            'status' => (string) $row['status'],
            'must_change_password' => (bool) $row['must_change_password'],
        ];
    }
}
