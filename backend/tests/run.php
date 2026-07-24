<?php

declare(strict_types=1);

require dirname(__DIR__) . '/src/bootstrap.php';

use App\Services\DutyRules;
use App\Services\FirebaseMessagingService;

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

test_case('Firebase service account loads from a base64 environment secret', function (): void {
    $previousEncoded = $_ENV['FIREBASE_SERVICE_ACCOUNT_JSON_BASE64'] ?? null;
    $previousPath = $_ENV['FIREBASE_SERVICE_ACCOUNT'] ?? null;
    $_ENV['FIREBASE_SERVICE_ACCOUNT_JSON_BASE64'] = base64_encode(json_encode([
        'type' => 'service_account',
        'project_id' => 'unit-test-project',
        'client_email' => 'unit-test@example.invalid',
        'private_key' => "-----BEGIN PRIVATE KEY-----\nunit-test\n-----END PRIVATE KEY-----\n",
    ], JSON_THROW_ON_ERROR));
    unset($_ENV['FIREBASE_SERVICE_ACCOUNT']);

    try {
        $method = new ReflectionMethod(FirebaseMessagingService::class, 'serviceAccount');
        $account = $method->invoke(new FirebaseMessagingService());
        assert_true(($account['project_id'] ?? null) === 'unit-test-project');
    } finally {
        if ($previousEncoded === null) {
            unset($_ENV['FIREBASE_SERVICE_ACCOUNT_JSON_BASE64']);
        } else {
            $_ENV['FIREBASE_SERVICE_ACCOUNT_JSON_BASE64'] = $previousEncoded;
        }
        if ($previousPath === null) {
            unset($_ENV['FIREBASE_SERVICE_ACCOUNT']);
        } else {
            $_ENV['FIREBASE_SERVICE_ACCOUNT'] = $previousPath;
        }
    }
});

test_case('invalid Firebase base64 configuration is rejected', function (): void {
    $previousEncoded = $_ENV['FIREBASE_SERVICE_ACCOUNT_JSON_BASE64'] ?? null;
    $_ENV['FIREBASE_SERVICE_ACCOUNT_JSON_BASE64'] = 'not-valid-base64%%%';

    try {
        $method = new ReflectionMethod(FirebaseMessagingService::class, 'serviceAccount');
        try {
            $method->invoke(new FirebaseMessagingService());
            throw new RuntimeException('Invalid Firebase configuration was accepted.');
        } catch (RuntimeException $exception) {
            assert_true(str_contains($exception->getMessage(), 'Invalid base64'));
        }
    } finally {
        if ($previousEncoded === null) {
            unset($_ENV['FIREBASE_SERVICE_ACCOUNT_JSON_BASE64']);
        } else {
            $_ENV['FIREBASE_SERVICE_ACCOUNT_JSON_BASE64'] = $previousEncoded;
        }
    }
});

test_case('Firebase keeps regular and sick announcements in separate threads', function (): void {
    $method = new ReflectionMethod(FirebaseMessagingService::class, 'messagePayload');
    $service = new FirebaseMessagingService();
    $regular = $method->invoke(
        $service,
        'test-token',
        'Neue Ankündigung',
        'Text',
        ['route' => 'announcements'],
        true,
        true,
        false
    );
    $sick = $method->invoke(
        $service,
        'test-token',
        'Krankmeldung im SSD',
        'Text',
        [
            'route' => 'announcements',
            'system_type' => 'duty_sick_reported',
        ],
        true,
        true,
        true
    );

    assert_true(
        ($regular['message']['apns']['payload']['aps']['thread-id'] ?? null) === 'ssd-announcements',
        'Regular announcement used the wrong APNs thread.'
    );
    assert_true(
        ($sick['message']['apns']['payload']['aps']['thread-id'] ?? null) === 'ssd-sick-reports',
        'Sick report was not separated from normal announcements.'
    );
    assert_true(
        ($sick['message']['android']['priority'] ?? null) === 'HIGH',
        'Sick report did not keep high Android priority.'
    );
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
