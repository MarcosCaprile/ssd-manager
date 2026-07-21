import 'package:intl/intl.dart';

class DateFormatters {
  DateFormatters._();

  static final DateFormat weekday = DateFormat.EEEE('de_DE');
  static final DateFormat date = DateFormat('dd.MM.yyyy', 'de_DE');
  static final DateFormat dateTime = DateFormat('dd.MM.yyyy HH:mm', 'de_DE');

  static String dutyDate(DateTime value) => date.format(value);
  static String dutyWeekday(DateTime value) => weekday.format(value);
  static String timestamp(DateTime value) => dateTime.format(value.toLocal());
}
