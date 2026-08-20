import 'dart:typed_data';

import '../core/api/api_client.dart';
import '../models/announcement.dart';
import '../models/announcement_report.dart';

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

  Future<void> report({
    required int announcementId,
    required AnnouncementReportReason reason,
    String? details,
  }) async {
    await _api.post(
      'announcements/$announcementId/reports',
      body: {
        'reason': reason.toJson(),
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
    );
  }

  Future<void> deleteOwn(int announcementId) async {
    await _api.delete('announcements/$announcementId');
  }

  Future<List<AnnouncementReport>> reports() async {
    final data = await _api.get('announcement-reports') as List<dynamic>;
    return data
        .map(
          (item) => AnnouncementReport.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> moderateReport({
    required int reportId,
    required AnnouncementModerationAction action,
  }) async {
    await _api.patch(
      'announcement-reports/$reportId',
      body: {'action': action.toJson()},
    );
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

  void evictAttachment(int attachmentId) {
    _attachmentCache.remove(attachmentId);
  }
}
