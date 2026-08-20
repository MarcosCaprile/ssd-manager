import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/models/announcement_report.dart';

void main() {
  test('parses an open announcement report for moderation', () {
    final report = AnnouncementReport.fromJson({
      'id': 5,
      'announcement_id': 42,
      'reason': 'privacy',
      'details': 'Enthält persönliche Daten.',
      'status': 'open',
      'created_at': '2026-08-20 08:15:00',
      'reporter_name': 'Rita Rettich',
      'sender_user_id': 7,
      'sender_name': 'Thomas Tomate',
      'sender_role': 'sanitaeter',
      'sender_status': 'active',
      'message': 'Beispielnachricht',
      'announcement_created_at': '2026-08-20 08:00:00',
      'is_moderated': false,
      'attachment_count': 2,
      'available_attachment_count': 2,
    });

    expect(report.isOpen, isTrue);
    expect(report.reason, AnnouncementReportReason.privacy);
    expect(report.reason.label, contains('Datenschutz'));
    expect(report.attachmentCount, 2);
  });

  test('serializes moderation actions for the API', () {
    expect(AnnouncementModerationAction.dismiss.toJson(), 'dismiss');
    expect(AnnouncementModerationAction.remove.toJson(), 'remove');
    expect(
      AnnouncementModerationAction.removeAndDeactivate.toJson(),
      'remove_and_deactivate',
    );
  });
}
