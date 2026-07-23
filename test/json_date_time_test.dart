import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/utils/json_date_time.dart';

void main() {
  test('treats database timestamps without a suffix as UTC', () {
    final parsed = parseUtcDateTime('2026-07-22 21:38:00');

    expect(parsed.isUtc, isTrue);
    expect(parsed, DateTime.utc(2026, 7, 22, 21, 38));
  });

  test('preserves timestamps that already contain UTC information', () {
    final parsed = parseUtcDateTime('2026-07-22T21:38:00Z');

    expect(parsed.isUtc, isTrue);
    expect(parsed, DateTime.utc(2026, 7, 22, 21, 38));
  });
}
