import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/core/push/push_message_policy.dart';

void main() {
  test('classifies normal and sick announcement pushes separately', () {
    expect(
      PushMessagePolicy.classify({'route': 'announcements'}),
      PushMessageKind.regularAnnouncement,
    );
    expect(
      PushMessagePolicy.classify({
        'route': 'announcements',
        'system_type': 'duty_sick_reported',
      }),
      PushMessageKind.sickReport,
    );
    expect(
      PushMessagePolicy.classify({
        'route': 'announcements',
        'notification_type': 'announcement_system_sick',
      }),
      PushMessageKind.sickReport,
    );
    expect(
      PushMessagePolicy.classify({'route': 'duty'}),
      PushMessageKind.other,
    );
  });

  test('suppresses only normal announcement pushes while chat is visible', () {
    expect(
      PushMessagePolicy.shouldShowPhoneNotification(
        kind: PushMessageKind.regularAnnouncement,
        announcementsVisible: true,
      ),
      isFalse,
    );
    expect(
      PushMessagePolicy.shouldShowPhoneNotification(
        kind: PushMessageKind.sickReport,
        announcementsVisible: true,
      ),
      isTrue,
    );
    expect(
      PushMessagePolicy.shouldShowPhoneNotification(
        kind: PushMessageKind.regularAnnouncement,
        announcementsVisible: false,
      ),
      isTrue,
    );
  });

  test('counts announcements as unread only outside the visible chat', () {
    expect(
      PushMessagePolicy.countsAsUnread(
        kind: PushMessageKind.regularAnnouncement,
        announcementsVisible: false,
      ),
      isTrue,
    );
    expect(
      PushMessagePolicy.countsAsUnread(
        kind: PushMessageKind.sickReport,
        announcementsVisible: false,
      ),
      isTrue,
    );
    expect(
      PushMessagePolicy.countsAsUnread(
        kind: PushMessageKind.sickReport,
        announcementsVisible: true,
      ),
      isFalse,
    );
    expect(
      PushMessagePolicy.countsAsUnread(
        kind: PushMessageKind.other,
        announcementsVisible: false,
      ),
      isFalse,
    );
  });
}
