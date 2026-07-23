<?php

declare(strict_types=1);

use App\Core\Config;
use App\Core\Database;

require dirname(__DIR__) . '/src/bootstrap.php';

$baseUrl = rtrim(getenv('SSD_API_TEST_BASE_URL') ?: 'http://127.0.0.1:8080/api/v1', '/');
$seedPassword = getenv('SSD_API_TEST_PASSWORD') ?: 'password';
$databaseHost = Config::env('DB_HOST', '127.0.0.1');
if (
    Config::env('APP_ENV') !== 'local'
    || !in_array(parse_url($baseUrl, PHP_URL_HOST), ['127.0.0.1', 'localhost', '::1'], true)
    || !in_array($databaseHost, ['127.0.0.1', 'localhost', '::1'], true)
) {
    fwrite(STDERR, '[FAIL] Duty-management smoke tests require a local API and local APP_ENV/database.' . PHP_EOL);
    exit(1);
}

$pdo = Database::connection();
$testDayIds = [];
$loginAttemptBaseline = (int) $pdo->query('SELECT COALESCE(MAX(id), 0) FROM login_attempts')->fetchColumn();

/**
 * @return array{status:int,body:array<string,mixed>}
 */
function duty_request(
    string $method,
    string $path,
    ?array $payload = null,
    ?string $accessToken = null,
): array {
    global $baseUrl;

    $headers = ['Accept: application/json'];
    if ($payload !== null) {
        $headers[] = 'Content-Type: application/json';
    }
    if ($accessToken !== null) {
        $headers[] = 'Authorization: Bearer ' . $accessToken;
    }
    $handle = curl_init($baseUrl . '/' . ltrim($path, '/'));
    curl_setopt_array($handle, [
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_POSTFIELDS => $payload === null ? null : json_encode($payload, JSON_THROW_ON_ERROR),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 10,
    ]);
    $rawBody = curl_exec($handle);
    if ($rawBody === false) {
        throw new RuntimeException('HTTP request failed: ' . curl_error($handle));
    }
    $status = curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    curl_close($handle);
    $body = json_decode($rawBody, true, flags: JSON_THROW_ON_ERROR);
    if (!is_array($body)) {
        throw new RuntimeException('Expected a JSON object from ' . $path);
    }
    return ['status' => $status, 'body' => $body];
}

function expect_duty_status(array $response, int $expected, string $label): array
{
    if ($response['status'] !== $expected) {
        $message = $response['body']['message'] ?? 'unexpected response';
        throw new RuntimeException("{$label}: expected HTTP {$expected}, got {$response['status']} ({$message})");
    }
    echo "[OK] {$label}" . PHP_EOL;
    return $response;
}

function duty_login(string $username, string $password): string
{
    $response = expect_duty_status(duty_request('POST', 'auth/login', [
        'identifier' => $username,
        'password' => $password,
        'device_name' => 'Duty-management smoke test',
        'platform' => 'cli',
    ]), 200, "{$username} login");
    $token = $response['body']['data']['access_token'] ?? null;
    if (!is_string($token)) {
        throw new RuntimeException("{$username} login returned no access token.");
    }
    return $token;
}

function next_weekday(DateTimeImmutable $date): DateTimeImmutable
{
    while (in_array((int) $date->format('N'), [6, 7], true)) {
        $date = $date->modify('+1 day');
    }
    return $date;
}

function remember_test_days(PDO $pdo, array &$ids, array $dates): void
{
    $statement = $pdo->prepare(
        'SELECT id FROM duty_days WHERE school_id = 1 AND duty_date IN (' .
        implode(',', array_fill(0, count($dates), '?')) . ')'
    );
    $statement->execute($dates);
    foreach ($statement->fetchAll() as $row) {
        $ids[] = (int) $row['id'];
    }
    $ids = array_values(array_unique($ids));
}

function cleanup_duty_management(
    PDO $pdo,
    array $dayIds,
    int $loginAttemptBaseline,
): void {
    if ($dayIds !== []) {
        $placeholders = implode(',', array_fill(0, count($dayIds), '?'));
        $pdo->prepare("DELETE FROM notification_logs WHERE duty_day_id IN ({$placeholders})")->execute($dayIds);
        $pdo->prepare("DELETE FROM duty_assignments WHERE duty_day_id IN ({$placeholders})")->execute($dayIds);
        $pdo->prepare("DELETE FROM audit_logs WHERE target_type = 'duty_day' AND target_id IN ({$placeholders})")
            ->execute($dayIds);
        $pdo->prepare("DELETE FROM duty_days WHERE id IN ({$placeholders})")->execute($dayIds);
    }
    $pdo->prepare('DELETE FROM user_devices WHERE device_name = :device_name')
        ->execute(['device_name' => 'Duty-management smoke test']);
    $pdo->prepare(
        'DELETE FROM login_attempts
         WHERE id > :baseline AND identifier IN ("lehrer", "leitung", "noah")'
    )->execute(['baseline' => $loginAttemptBaseline]);
}

$failure = null;
try {
    $timezone = new DateTimeZone(Config::env('SCHOOL_TIMEZONE', 'Europe/Berlin') ?? 'Europe/Berlin');
    $today = new DateTimeImmutable('today', $timezone);
    $eventDate = next_weekday($today->modify('+400 days'));
    $historyDate = next_weekday($today->modify('-300 days'));
    $closureStart = next_weekday($today->modify('+500 days'));
    $closureEnd = $closureStart->modify('+4 days');
    $weekend = $today;
    while (!in_array((int) $weekend->format('N'), [6, 7], true)) {
        $weekend = $weekend->modify('+1 day');
    }
    $unnamedDate = next_weekday($today->modify('+600 days'));
    $oversizedDate = next_weekday($unnamedDate->modify('+2 days'));

    $teacher = duty_login('lehrer', $seedPassword);
    $lead = duty_login('leitung', $seedPassword);
    $firstAider = duty_login('noah', $seedPassword);

    $event = expect_duty_status(duty_request('POST', 'duties', [
        'date' => $eventDate->format('Y-m-d'),
        'capacity' => 5,
        'title' => 'Sportfest',
        'description' => 'Treffpunkt am Sanitätsraum.',
    ], $teacher), 201, 'teacher creates named duty day');
    $eventData = $event['body']['data'] ?? [];
    if (
        ($eventData['title'] ?? null) !== 'Sportfest'
        || ($eventData['description'] ?? null) !== 'Treffpunkt am Sanitätsraum.'
        || (int) ($eventData['capacity'] ?? 0) !== 5
        || ($eventData['is_closed'] ?? true) !== false
    ) {
        throw new RuntimeException('Created duty day did not preserve its editable fields.');
    }
    remember_test_days($pdo, $testDayIds, [$eventDate->format('Y-m-d')]);

    expect_duty_status(duty_request('POST', 'duties', [
        'date' => $eventDate->format('Y-m-d'),
        'capacity' => 3,
        'title' => 'Doppelter Testtag',
    ], $teacher), 409, 'duplicate duty day is rejected');
    expect_duty_status(duty_request('POST', 'duties', [
        'date' => $eventDate->format('Y-m-d'),
        'capacity' => 3,
        'title' => 'Nicht erlaubt',
    ], $firstAider), 403, 'first-aider cannot create duty day');

    expect_duty_status(duty_request('POST', 'duties', [
        'date' => $unnamedDate->format('Y-m-d'),
        'capacity' => 3,
    ], $teacher), 422, 'new duty day requires a name');
    expect_duty_status(duty_request('POST', 'duties', [
        'date' => $oversizedDate->format('Y-m-d'),
        'capacity' => 51,
        'title' => 'Zu große Besetzung',
    ], $teacher), 422, 'duty capacity above 50 is rejected');

    $weekendEvent = expect_duty_status(duty_request('POST', 'duties', [
        'date' => $weekend->format('Y-m-d'),
        'capacity' => 50,
        'title' => 'Wochenendturnier',
        'description' => 'Sanitätsdienst am Wochenende.',
    ], $teacher), 201, 'teacher creates named weekend duty with maximum capacity');
    if (
        ($weekendEvent['body']['data']['title'] ?? null) !== 'Wochenendturnier'
        || (int) ($weekendEvent['body']['data']['capacity'] ?? 0) !== 50
        || ($weekendEvent['body']['data']['is_active'] ?? false) !== true
    ) {
        throw new RuntimeException('Weekend duty did not preserve its event fields.');
    }
    remember_test_days($pdo, $testDayIds, [$weekend->format('Y-m-d')]);
    expect_duty_status(
        duty_request(
            'POST',
            'duties/' . $weekend->format('Y-m-d') . '/self',
            accessToken: $firstAider
        ),
        201,
        'first-aider can book explicit weekend duty'
    );
    expect_duty_status(
        duty_request(
            'POST',
            'duties/' . $weekend->format('Y-m-d') . '/reset',
            accessToken: $teacher
        ),
        409,
        'occupied weekend event cannot be removed'
    );
    $weekendAssignment = $pdo->prepare(
        'SELECT da.id
         FROM duty_assignments da
         JOIN duty_days dd ON dd.id = da.duty_day_id
         WHERE dd.school_id = 1 AND dd.duty_date = :date
           AND da.user_id = 3 AND da.status = "planned"
         LIMIT 1'
    );
    $weekendAssignment->execute(['date' => $weekend->format('Y-m-d')]);
    $weekendAssignmentId = (int) $weekendAssignment->fetchColumn();
    if ($weekendAssignmentId < 1) {
        throw new RuntimeException('Weekend test assignment was not stored.');
    }
    $pdo->prepare('DELETE FROM duty_assignments WHERE id = :id')
        ->execute(['id' => $weekendAssignmentId]);
    $removedWeekend = expect_duty_status(
        duty_request(
            'POST',
            'duties/' . $weekend->format('Y-m-d') . '/reset',
            accessToken: $lead
        ),
        200,
        'unoccupied weekend event can be removed'
    );
    if (($removedWeekend['body']['data']['is_active'] ?? true) !== false) {
        throw new RuntimeException('Removed weekend event is still active.');
    }
    expect_duty_status(duty_request('POST', 'duties', [
        'date' => $weekend->format('Y-m-d'),
        'capacity' => 50,
        'title' => 'Wochenendturnier',
        'description' => 'Sanitätsdienst am Wochenende.',
    ], $teacher), 201, 'removed weekend event can be recreated');
    remember_test_days($pdo, $testDayIds, [$weekend->format('Y-m-d')]);

    expect_duty_status(duty_request(
        'POST',
        'duties/' . $eventDate->format('Y-m-d') . '/assignments',
        ['user_id' => 3],
        $teacher
    ), 201, 'teacher assigns first-aider before closure attempt');
    expect_duty_status(duty_request('PATCH', 'duties/' . $eventDate->format('Y-m-d'), [
        'capacity' => 5,
        'title' => 'Sportfest',
        'is_closed' => true,
    ], $teacher), 409, 'occupied duty day cannot be closed');
    $assignment = $pdo->prepare(
        'SELECT id FROM duty_assignments
         WHERE duty_day_id = :day_id AND user_id = 3 AND status = "planned" LIMIT 1'
    );
    $assignment->execute(['day_id' => $testDayIds[0]]);
    $assignmentId = (int) $assignment->fetchColumn();
    expect_duty_status(duty_request(
        'DELETE',
        'duties/' . $eventDate->format('Y-m-d') . '/assignments/' . $assignmentId,
        accessToken: $teacher
    ), 200, 'teacher removes assignment before editing day');

    $updated = expect_duty_status(duty_request('PATCH', 'duties/' . $eventDate->format('Y-m-d'), [
        'capacity' => 4,
        'title' => 'Bundesjugendspiele',
        'description' => 'Zwei Stationen absichern.',
        'is_closed' => false,
    ], $lead), 200, 'lead edits duty day');
    if (
        ($updated['body']['data']['title'] ?? null) !== 'Bundesjugendspiele'
        || (int) ($updated['body']['data']['capacity'] ?? 0) !== 4
    ) {
        throw new RuntimeException('Updated duty day fields were not returned.');
    }
    $resetEvent = expect_duty_status(
        duty_request(
            'POST',
            'duties/' . $eventDate->format('Y-m-d') . '/reset',
            accessToken: $lead
        ),
        200,
        'lead resets event to a normal duty day'
    );
    if (
        ($resetEvent['body']['data']['title'] ?? null) !== null
        || ($resetEvent['body']['data']['description'] ?? null) !== null
        || ($resetEvent['body']['data']['is_closed'] ?? true) !== false
        || ($resetEvent['body']['data']['is_active'] ?? false) !== true
    ) {
        throw new RuntimeException('Reset duty day still contains event metadata.');
    }
    expect_duty_status(duty_request('PATCH', 'duties/' . $eventDate->format('Y-m-d'), [
        'capacity' => 4,
        'is_closed' => false,
    ], $firstAider), 403, 'first-aider cannot edit duty day');

    expect_duty_status(duty_request('POST', 'duties', [
        'date' => $historyDate->format('Y-m-d'),
        'capacity' => 2,
        'title' => 'Vergangener Testtag',
    ], $teacher), 201, 'teacher creates past test day');
    remember_test_days($pdo, $testDayIds, [$historyDate->format('Y-m-d')]);
    $history = expect_duty_status(
        duty_request(
            'GET',
            'duties/history?date=' . rawurlencode($historyDate->format('Y-m-d')),
            accessToken: $teacher
        ),
        200,
        'history can be filtered by exact date'
    );
    $historyItems = $history['body']['data'] ?? null;
    if (
        !is_array($historyItems)
        || count($historyItems) !== 1
        || ($historyItems[0]['date'] ?? null) !== $historyDate->format('Y-m-d')
    ) {
        throw new RuntimeException('History date filter returned unexpected days.');
    }

    expect_duty_status(duty_request('POST', 'duties/closures', [
        'start_date' => $closureStart->format('Y-m-d'),
        'end_date' => $closureEnd->format('Y-m-d'),
        'name' => 'Testferien',
        'description' => 'Die Schule bleibt geschlossen.',
    ], $firstAider), 403, 'first-aider cannot create closure range');
    expect_duty_status(duty_request('POST', 'duties/closures', [
        'start_date' => $closureStart->format('Y-m-d'),
        'end_date' => $closureEnd->format('Y-m-d'),
        'name' => 'Testferien',
        'description' => 'Die Schule bleibt geschlossen.',
    ], $teacher), 201, 'teacher creates closure range');

    $closureDates = [];
    for ($date = $closureStart; $date <= $closureEnd; $date = $date->modify('+1 day')) {
        if (!in_array((int) $date->format('N'), [6, 7], true)) {
            $closureDates[] = $date->format('Y-m-d');
        }
    }
    remember_test_days($pdo, $testDayIds, $closureDates);
    foreach ($closureDates as $date) {
        $details = expect_duty_status(
            duty_request('GET', 'duties/' . $date, accessToken: $teacher),
            200,
            "closure details for {$date}"
        );
        if (
            ($details['body']['data']['is_closed'] ?? false) !== true
            || ($details['body']['data']['is_active'] ?? true) !== false
            || ($details['body']['data']['title'] ?? null) !== 'Testferien'
        ) {
            throw new RuntimeException("Closure details for {$date} are incomplete.");
        }
    }
    expect_duty_status(duty_request(
        'POST',
        'duties/' . $closureDates[0] . '/assignments',
        ['user_id' => 3],
        $teacher
    ), 409, 'closed day rejects administrative assignment');
    expect_duty_status(
        duty_request('POST', 'duties/closures/reset', [
            'start_date' => $closureStart->format('Y-m-d'),
            'end_date' => $closureEnd->format('Y-m-d'),
        ], $firstAider),
        403,
        'first-aider cannot reset closure range'
    );
    expect_duty_status(
        duty_request('POST', 'duties/closures/reset', [
            'start_date' => $closureStart->format('Y-m-d'),
            'end_date' => $closureEnd->format('Y-m-d'),
        ], $teacher),
        200,
        'teacher resets closure range'
    );
    foreach ($closureDates as $date) {
        $details = expect_duty_status(
            duty_request('GET', 'duties/' . $date, accessToken: $teacher),
            200,
            "reset closure details for {$date}"
        );
        if (
            ($details['body']['data']['is_closed'] ?? true) !== false
            || ($details['body']['data']['is_active'] ?? false) !== true
            || ($details['body']['data']['title'] ?? null) !== null
        ) {
            throw new RuntimeException("Reset closure details for {$date} are incomplete.");
        }
    }

    $upcoming = expect_duty_status(
        duty_request('GET', 'duties/upcoming', accessToken: $teacher),
        200,
        'upcoming duty list'
    );
    $foundWeekendEvent = false;
    foreach (($upcoming['body']['data'] ?? []) as $day) {
        $weekday = (int) (new DateTimeImmutable((string) $day['date']))->format('N');
        if (in_array($weekday, [6, 7], true)) {
            if (
                ($day['date'] ?? null) !== $weekend->format('Y-m-d')
                || ($day['title'] ?? null) !== 'Wochenendturnier'
            ) {
                throw new RuntimeException('Upcoming duty list contains an unnamed weekend.');
            }
            $foundWeekendEvent = true;
        }
    }
    if (!$foundWeekendEvent) {
        throw new RuntimeException('Upcoming duty list omitted the explicit weekend event.');
    }
    echo '[OK] upcoming duty list contains only the explicit named weekend event' . PHP_EOL;

    expect_duty_status(
        duty_request('POST', 'auth/logout', accessToken: $teacher),
        200,
        'teacher logout'
    );
    expect_duty_status(
        duty_request('POST', 'auth/logout', accessToken: $lead),
        200,
        'lead logout'
    );
    expect_duty_status(
        duty_request('POST', 'auth/logout', accessToken: $firstAider),
        200,
        'first-aider logout'
    );
} catch (Throwable $exception) {
    $failure = $exception;
} finally {
    try {
        cleanup_duty_management($pdo, $testDayIds, $loginAttemptBaseline);
        echo '[OK] local duty-management test data cleaned up' . PHP_EOL;
    } catch (Throwable $cleanupException) {
        $failure ??= $cleanupException;
    }
}

if ($failure !== null) {
    fwrite(STDERR, '[FAIL] ' . $failure->getMessage() . PHP_EOL);
    exit(1);
}

echo 'Duty-management API smoke test passed.' . PHP_EOL;
