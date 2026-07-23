import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/utils/duty_rules.dart';

void main() {
  test('weekends are blocked', () {
    expect(DutyRules.isWeekend(DateTime(2026, 7, 18)), isTrue);
    expect(DutyRules.isWeekend(DateTime(2026, 7, 19)), isTrue);
    expect(DutyRules.isWeekend(DateTime(2026, 7, 20)), isFalse);
  });

  test('booking window includes today and the next 13 days', () {
    final now = DateTime(2026, 7, 17, 10);
    expect(
      DutyRules.isWithinUpcomingWindow(now, DateTime(2026, 7, 17)),
      isTrue,
    );
    expect(
      DutyRules.isWithinUpcomingWindow(now, DateTime(2026, 7, 30)),
      isTrue,
    );
    expect(
      DutyRules.isWithinUpcomingWindow(now, DateTime(2026, 7, 31)),
      isFalse,
    );
    expect(
      DutyRules.isWithinUpcomingWindow(now, DateTime(2026, 7, 16)),
      isFalse,
    );
  });

  test('regular cancellation requires at least 48 hours', () {
    final now = DateTime(2026, 7, 17);
    expect(DutyRules.canCancelRegularly(now, DateTime(2026, 7, 19)), isTrue);
    expect(
      DutyRules.canCancelRegularly(
        now.add(const Duration(minutes: 1)),
        DateTime(2026, 7, 19),
      ),
      isFalse,
    );
  });

  test('sick reporting is allowed inside 48 hours but not in the past', () {
    final now = DateTime(2026, 7, 17, 8);
    expect(DutyRules.canReportSick(now, DateTime(2026, 7, 18)), isTrue);
    expect(DutyRules.canReportSick(now, DateTime(2026, 7, 16)), isFalse);
  });
}
