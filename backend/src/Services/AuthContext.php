<?php

declare(strict_types=1);

namespace App\Services;

final class AuthContext
{
    /**
     * @param array<string,mixed> $user
     * @param array<string,mixed> $device
     */
    public function __construct(
        public readonly array $user,
        public readonly array $device,
    ) {
    }

    public function userId(): int
    {
        return (int) $this->user['id'];
    }

    public function schoolId(): int
    {
        return (int) $this->user['school_id'];
    }

    public function role(): string
    {
        return (string) $this->user['role'];
    }

    public function deviceId(): int
    {
        return (int) $this->device['id'];
    }

    public function canManageUsers(): bool
    {
        return in_array($this->role(), ['sani_leitung', 'teacher'], true);
    }

    public function canManageDuties(): bool
    {
        return in_array($this->role(), ['sani_leitung', 'teacher'], true);
    }

    public function canManageRoles(): bool
    {
        return in_array($this->role(), ['sani_leitung', 'teacher'], true);
    }

    public function canAssignSelfToDuty(): bool
    {
        return in_array($this->role(), ['sanitaeter', 'sani_leitung'], true);
    }
}
