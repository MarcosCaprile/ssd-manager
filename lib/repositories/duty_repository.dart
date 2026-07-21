import '../core/api/api_client.dart';
import '../models/duty_day.dart';

class DutyRepository {
  DutyRepository(this._api);

  final ApiClient _api;

  Future<List<DutyDay>> upcoming() async {
    final data = await _api.get('duties/upcoming') as List<dynamic>;
    return data.map((item) => DutyDay.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<DutyDay>> history() async {
    final data = await _api.get('duties/history') as List<dynamic>;
    return data.map((item) => DutyDay.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<DutyDay> details(DateTime date) async {
    final data = await _api.get('duties/${_dateParam(date)}') as Map<String, dynamic>;
    return DutyDay.fromJson(data);
  }

  Future<void> selfAssign(DateTime date) => _api.post('duties/${_dateParam(date)}/self');
  Future<void> selfCancel(DateTime date) => _api.delete('duties/${_dateParam(date)}/self');
  Future<void> sickReport(DateTime date) => _api.post('duties/${_dateParam(date)}/sick');

  Future<void> adminAssign(DateTime date, int userId) {
    return _api.post('duties/${_dateParam(date)}/assignments', body: {'user_id': userId});
  }

  Future<void> adminRemove(DateTime date, int assignmentId) {
    return _api.delete('duties/${_dateParam(date)}/assignments/$assignmentId');
  }

  String _dateParam(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
