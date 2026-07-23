import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/utils/date_formatters.dart';

void main() {
  test('formats duty dates with German weekday names without locale setup', () {
    final date = DateTime(2026, 7, 23);

    expect(DateFormatters.dutyWeekday(date), 'Donnerstag');
    expect(DateFormatters.dutyDate(date), '23.07.2026');
  });

  test('formats local timestamps with leading zeroes', () {
    final timestamp = DateTime(2026, 1, 2, 9, 5);

    expect(DateFormatters.timestamp(timestamp), '02.01.2026 09:05');
  });

  test('shows only the time for chat messages from today', () {
    final timestamp = DateTime(2026, 7, 23, 9, 5);
    final now = DateTime(2026, 7, 23, 18, 30);

    expect(DateFormatters.chatTimestamp(timestamp, now: now), '09:05');
  });

  test('adds the short date to older chat messages', () {
    final timestamp = DateTime(2026, 7, 22, 9, 5);
    final now = DateTime(2026, 7, 23, 18, 30);

    expect(DateFormatters.chatTimestamp(timestamp, now: now), '22.07. 09:05');
  });
}
