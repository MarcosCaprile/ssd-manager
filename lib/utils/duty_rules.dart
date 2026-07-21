class DutyRules {
  DutyRules._();

  static const capacity = 3;

  static bool isWeekend(DateTime day) =>
      day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

  static DateTime onlyDate(DateTime value) => DateTime(value.year, value.month, value.day);

  static bool isWithinUpcomingWindow(DateTime now, DateTime day) {
    final today = onlyDate(now);
    final target = onlyDate(day);
    final lastAllowed = today.add(const Duration(days: 13));
    return !target.isBefore(today) && !target.isAfter(lastAllowed);
  }

  static bool canBook(DateTime now, DateTime day) =>
      !isWeekend(day) && isWithinUpcomingWindow(now, day);

  static bool canCancelRegularly(DateTime now, DateTime day) {
    final dutyStart = DateTime(day.year, day.month, day.day);
    return dutyStart.difference(now).inMinutes >= 48 * 60;
  }

  static bool canReportSick(DateTime now, DateTime day) {
    final today = onlyDate(now);
    final target = onlyDate(day);
    if (target.isBefore(today)) return false;
    return !canCancelRegularly(now, day);
  }
}
