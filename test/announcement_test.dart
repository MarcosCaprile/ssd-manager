import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/models/announcement.dart';

void main() {
  test('parses announcement attachment metadata', () {
    final announcement = Announcement.fromJson({
      'id': 42,
      'sender_user_id': 7,
      'sender_name': 'Thomas Tomate',
      'sender_role': 'sanitaeter',
      'message': 'Bitte beachten',
      'created_at': '2026-07-23 17:05:00',
      'attachments': [
        {
          'id': 11,
          'file_name': 'einsatzplan.png',
          'mime_type': 'image/png',
          'size_bytes': 12345,
          'is_image': true,
        },
        {
          'id': 12,
          'file_name': 'hinweis.pdf',
          'mime_type': 'application/pdf',
          'size_bytes': 67890,
          'is_image': false,
        },
      ],
    });

    expect(announcement.id, 42);
    expect(announcement.senderName, 'Thomas Tomate');
    expect(announcement.attachments, hasLength(2));
    expect(announcement.attachments.first.fileName, 'einsatzplan.png');
    expect(announcement.attachments.first.isImage, isTrue);
    expect(announcement.attachments.first.isDeleted, isFalse);
    expect(announcement.attachments.last.mimeType, 'application/pdf');
  });

  test('supports attachment-only announcements', () {
    final announcement = Announcement.fromJson({
      'id': 43,
      'sender_user_id': 7,
      'sender_name': 'Thomas Tomate',
      'sender_role': 'sanitaeter',
      'message': '',
      'created_at': '2026-07-23 17:05:00',
      'attachments': [
        {
          'id': 13,
          'file_name': 'foto.jpg',
          'mime_type': 'image/jpeg',
          'size_bytes': 100,
          'is_image': true,
        },
      ],
    });

    expect(announcement.message, isEmpty);
    expect(announcement.attachments.single.isImage, isTrue);
  });

  test('parses deleted attachment markers', () {
    final announcement = Announcement.fromJson({
      'id': 44,
      'sender_user_id': 7,
      'sender_name': 'Thomas Tomate',
      'sender_role': 'sanitaeter',
      'message': '',
      'created_at': '2026-07-23 17:05:00',
      'attachments': [
        {
          'id': 14,
          'file_name': 'geloescht.pdf',
          'mime_type': 'application/pdf',
          'size_bytes': 500,
          'is_image': false,
          'is_deleted': true,
        },
      ],
    });

    expect(announcement.attachments.single.isDeleted, isTrue);
  });

  test('parses sick-report system announcements', () {
    final announcement = Announcement.fromJson({
      'id': 45,
      'sender_user_id': 7,
      'sender_name': 'Thomas Tomate',
      'sender_role': 'sanitaeter',
      'message':
          'Thomas T. hat sich für den Dienst am 24.07.2026 krankgemeldet. '
          'Es sind noch 2 Sanis für diesen Tag eingetragen.',
      'message_type': 'system',
      'system_type': 'duty_sick_reported',
      'created_at': '2026-07-23 17:05:00',
      'attachments': <dynamic>[],
    });

    expect(announcement.isSystem, isTrue);
    expect(announcement.systemType, 'duty_sick_reported');
  });

  test('parses moderation and personal report markers', () {
    final announcement = Announcement.fromJson({
      'id': 46,
      'sender_user_id': 8,
      'sender_name': 'Rita Rettich',
      'sender_role': 'sanitaeter',
      'message': 'Dieser Inhalt wurde von der Schulmoderation entfernt.',
      'message_type': 'user',
      'is_moderated': true,
      'reported_by_me': true,
      'created_at': '2026-07-23 17:05:00',
      'attachments': <dynamic>[],
    });

    expect(announcement.isModerated, isTrue);
    expect(announcement.reportedByMe, isTrue);
    expect(announcement.copyWith(reportedByMe: false).reportedByMe, isFalse);
  });
}
