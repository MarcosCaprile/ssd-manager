<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Services\DutyRules;

$tests = [];

function test_case(string $name, callable $fn): void
{
    global $tests;
    $tests[$name] = $fn;
}

function assert_true(bool $value, string $message = 'Expected true'): void
{
    if (!$value) {
        throw new RuntimeException($message);
    }
}

function assert_false(bool $value, string $message = 'Expected false'): void
{
    if ($value) {
        throw new RuntimeException($message);
    }
}

$rules = new DutyRules('Europe/Berlin');

test_case('weekends are blocked', function () use ($rules): void {
    assert_true($rules->isWeekend('2026-07-18'));
    assert_true($rules->isWeekend('2026-07-19'));
    assert_false($rules->isWeekend('2026-07-20'));
});

test_case('booking window includes today and next 13 days', function () use ($rules): void {
    $now = new DateTimeImmutable('2026-07-17 10:00:00', new DateTimeZone('Europe/Berlin'));
    assert_true($rules->isWithinUpcomingWindow('2026-07-17', $now));
    assert_true($rules->isWithinUpcomingWindow('2026-07-30', $now));
    assert_false($rules->isWithinUpcomingWindow('2026-07-31', $now));
    assert_false($rules->isWithinUpcomingWindow('2026-07-16', $now));
});

test_case('regular cancellation requires at least 48 hours', function () use ($rules): void {
    $now = new DateTimeImmutable('2026-07-17 00:00:00', new DateTimeZone('Europe/Berlin'));
    assert_true($rules->canCancelRegularly('2026-07-19', $now));
    $late = new DateTimeImmutable('2026-07-17 00:01:00', new DateTimeZone('Europe/Berlin'));
    assert_false($rules->canCancelRegularly('2026-07-19', $late));
});

test_case('sick report is allowed inside 48 hours but not in the past', function () use ($rules): void {
    $now = new DateTimeImmutable('2026-07-17 08:00:00', new DateTimeZone('Europe/Berlin'));
    assert_true($rules->canReportSick('2026-07-18', $now));
    assert_false($rules->canReportSick('2026-07-16', $now));
});

$failed = 0;
foreach ($tests as $name => $test) {
    try {
        $test();
        echo "[OK] {$name}" . PHP_EOL;
    } catch (Throwable $exception) {
        $failed++;
        echo "[FAIL] {$name}: {$exception->getMessage()}" . PHP_EOL;
    }
}

if ($failed > 0) {
    exit(1);
}

echo count($tests) . " tests passed." . PHP_EOL;
