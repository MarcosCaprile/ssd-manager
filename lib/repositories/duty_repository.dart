import '../core/api/api_client.dart';
import '../models/duty_day.dart';

class DutyRepository {
  DutyRepository(this._api);

  final ApiClient _api;

  Future<List<DutyDay>> upcoming() async {
    final data = await _api.get('duties/upcoming') as List<dynamic>;
    return data
        .map((item) => DutyDay.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<DutyDay>> history({DateTime? date}) async {
    final data =
        await _api.get(
              'duties/history',
              query: date == null ? null : {'date': _dateParam(date)},
            )
            as List<dynamic>;
    return data
        .map((item) => DutyDay.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DutyDay> details(DateTime date) async {
    final data =
        await _api.get('duties/${_dateParam(date)}') as Map<String, dynamic>;
    return DutyDay.fromJson(data);
  }

  Future<void> selfAssign(DateTime date) =>
      _api.post('duties/${_dateParam(date)}/self');
  Future<void> selfCancel(DateTime date) =>
      _api.delete('duties/${_dateParam(date)}/self');
  Future<void> sickReport(DateTime date) =>
      _api.post('duties/${_dateParam(date)}/sick');

  Future<void> adminAssign(DateTime date, int userId) {
    return _api.post(
      'duties/${_dateParam(date)}/assignments',
      body: {'user_id': userId},
    );
  }

  Future<void> adminRemove(DateTime date, int assignmentId) {
    return _api.delete('duties/${_dateParam(date)}/assignments/$assignmentId');
  }

  Future<DutyDay> createDay({
    required DateTime date,
    required int capacity,
    String? title,
    String? description,
  }) async {
    final data =
        await _api.post(
              'duties',
              body: {
                'date': _dateParam(date),
                'capacity': capacity,
                'title': _emptyToNull(title),
                'description': _emptyToNull(description),
              },
            )
            as Map<String, dynamic>;
    return DutyDay.fromJson(data);
  }

  Future<DutyDay> updateDay({
    required DateTime date,
    required int capacity,
    required bool isClosed,
    String? title,
    String? description,
  }) async {
    final data =
        await _api.patch(
              'duties/${_dateParam(date)}',
              body: {
                'capacity': capacity,
                'title': _emptyToNull(title),
                'description': _emptyToNull(description),
                'is_closed': isClosed,
              },
            )
            as Map<String, dynamic>;
    return DutyDay.fromJson(data);
  }

  Future<void> createClosureRange({
    required DateTime startDate,
    required DateTime endDate,
    required String name,
    String? description,
  }) {
    return _api.post(
      'duties/closures',
      body: {
        'start_date': _dateParam(startDate),
        'end_date': _dateParam(endDate),
        'name': name.trim(),
        'description': _emptyToNull(description),
      },
    );
  }

  Future<DutyDay> resetDay(DateTime date) async {
    final data =
        await _api.post('duties/${_dateParam(date)}/reset')
            as Map<String, dynamic>;
    return DutyDay.fromJson(data);
  }

  Future<void> resetClosureRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _api.post(
      'duties/closures/reset',
      body: {
        'start_date': _dateParam(startDate),
        'end_date': _dateParam(endDate),
      },
    );
  }

  String? _emptyToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _dateParam(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
