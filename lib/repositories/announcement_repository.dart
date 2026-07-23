import 'dart:typed_data';

import '../core/api/api_client.dart';
import '../models/announcement.dart';

class AnnouncementRepository {
  AnnouncementRepository(this._api);

  final ApiClient _api;
  final Map<int, Uint8List> _attachmentCache = {};

  Future<List<Announcement>> latest() async {
    final data = await _api.get('announcements') as List<dynamic>;
    return data
        .map((item) => Announcement.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AnnouncementAttachment> uploadAttachment({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final data =
        await _api.uploadFile(
              'announcements/attachments',
              field: 'attachment',
              fileName: fileName,
              bytes: bytes,
            )
            as Map<String, dynamic>;
    return AnnouncementAttachment.fromJson(data);
  }

  Future<Announcement> send({
    required String message,
    List<int> attachmentIds = const [],
  }) async {
    final data =
        await _api.post(
              'announcements',
              body: {'message': message, 'attachment_ids': attachmentIds},
            )
            as Map<String, dynamic>;
    return Announcement.fromJson(data);
  }

  Future<Uint8List> attachmentBytes(int attachmentId) async {
    final cached = _attachmentCache[attachmentId];
    if (cached != null) return cached;
    final bytes = await _api.getBytes(
      'announcements/attachments/$attachmentId',
    );
    _attachmentCache[attachmentId] = bytes;
    return bytes;
  }
}
