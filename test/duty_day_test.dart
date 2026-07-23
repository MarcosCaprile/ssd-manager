import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/models/duty_day.dart';

void main() {
  test('parses editable duty-day fields and closure status', () {
    final day = DutyDay.fromJson({
      'date': '2026-10-05',
      'title': 'Herbstferien',
      'description': 'Die Schule bleibt geschlossen.',
      'capacity': 4,
      'is_active': 0,
      'is_closed': 1,
      'assignments': <dynamic>[],
    });

    expect(day.date, DateTime(2026, 10, 5));
    expect(day.title, 'Herbstferien');
    expect(day.description, 'Die Schule bleibt geschlossen.');
    expect(day.capacity, 4);
    expect(day.isActive, isFalse);
    expect(day.isClosed, isTrue);
    expect(day.freeSlots, 4);
  });

  test('normalizes empty optional duty-day text to null', () {
    final day = DutyDay.fromJson({
      'date': '2026-10-06',
      'title': '   ',
      'description': null,
      'capacity': 3,
      'is_active': true,
      'is_closed': false,
      'assignments': <dynamic>[],
    });

    expect(day.title, isNull);
    expect(day.description, isNull);
    expect(day.isActive, isTrue);
    expect(day.isClosed, isFalse);
  });
}
