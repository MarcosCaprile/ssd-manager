<?php

declare(strict_types=1);

namespace App\Services;

final class DutyRules
{
    public const CAPACITY = 3;

    public function __construct(private readonly string $timezone = 'Europe/Berlin')
    {
    }

    public function isWeekend(string $date): bool
    {
        $day = new \DateTimeImmutable($date, new \DateTimeZone($this->timezone));
        return in_array((int) $day->format('N'), [6, 7], true);
    }

    public function isWithinUpcomingWindow(string $date, ?\DateTimeImmutable $now = null): bool
    {
        $now ??= new \DateTimeImmutable('now', new \DateTimeZone($this->timezone));
        $today = $now->setTime(0, 0);
        $target = new \DateTimeImmutable($date, new \DateTimeZone($this->timezone));
        $last = $today->modify('+13 days');
        return $target >= $today && $target <= $last;
    }

    public function canBook(string $date, ?\DateTimeImmutable $now = null): bool
    {
        return !$this->isWeekend($date) && $this->isWithinUpcomingWindow($date, $now);
    }

    public function canCancelRegularly(string $date, ?\DateTimeImmutable $now = null): bool
    {
        $now ??= new \DateTimeImmutable('now', new \DateTimeZone($this->timezone));
        $dutyStart = new \DateTimeImmutable($date . ' 00:00:00', new \DateTimeZone($this->timezone));
        return ($dutyStart->getTimestamp() - $now->getTimestamp()) >= 48 * 3600;
    }

    public function canReportSick(string $date, ?\DateTimeImmutable $now = null): bool
    {
        $now ??= new \DateTimeImmutable('now', new \DateTimeZone($this->timezone));
        $today = $now->setTime(0, 0);
        $target = new \DateTimeImmutable($date, new \DateTimeZone($this->timezone));
        return $target >= $today && !$this->canCancelRegularly($date, $now);
    }
}
