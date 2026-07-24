enum PushMessageKind { regularAnnouncement, sickReport, other }

class PushMessagePolicy {
  const PushMessagePolicy._();

  static PushMessageKind classify(Map<String, dynamic> data) {
    if (data['route'] != 'announcements') {
      return PushMessageKind.other;
    }
    if (data['system_type'] == 'duty_sick_reported' ||
        data['notification_type'] == 'announcement_system_sick') {
      return PushMessageKind.sickReport;
    }
    return PushMessageKind.regularAnnouncement;
  }

  static bool shouldShowPhoneNotification({
    required PushMessageKind kind,
    required bool announcementsVisible,
  }) {
    return kind != PushMessageKind.regularAnnouncement || !announcementsVisible;
  }

  static bool countsAsUnread({
    required PushMessageKind kind,
    required bool announcementsVisible,
  }) {
    return kind != PushMessageKind.other && !announcementsVisible;
  }
}
