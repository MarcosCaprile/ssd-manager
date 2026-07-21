import '../core/api/api_client.dart';
import '../models/announcement.dart';

class AnnouncementRepository {
  AnnouncementRepository(this._api);

  final ApiClient _api;

  Future<List<Announcement>> latest() async {
    final data = await _api.get('announcements') as List<dynamic>;
    return data.map((item) => Announcement.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Announcement> send(String message) async {
    final data = await _api.post('announcements', body: {'message': message}) as Map<String, dynamic>;
    return Announcement.fromJson(data);
  }
}
