class DateFormatters {
  DateFormatters._();

  static const _weekdays = <String>[
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];

  static String dutyDate(DateTime value) => _date(value);

  static String dutyWeekday(DateTime value) => _weekdays[value.weekday - 1];

  static String timestamp(DateTime value) {
    final local = value.toLocal();
    return '${_date(local)} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  static String chatTimestamp(DateTime value, {DateTime? now}) {
    final local = value.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
    if (local.year == current.year &&
        local.month == current.month &&
        local.day == current.day) {
      return time;
    }
    return '${_twoDigits(local.day)}.${_twoDigits(local.month)}. $time';
  }

  static String chatDayLabel(DateTime value, {DateTime? now}) {
    final local = value.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(current.year, current.month, current.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Heute';
    if (difference == 1) return 'Gestern';
    return '${dutyWeekday(local)}, ${_date(local)}';
  }

  static String _date(DateTime value) {
    return '${_twoDigits(value.day)}.${_twoDigits(value.month)}.${value.year.toString().padLeft(4, '0')}';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
