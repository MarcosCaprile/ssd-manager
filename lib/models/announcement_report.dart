import '../utils/json_date_time.dart';

enum AnnouncementReportReason {
  bullying,
  inappropriate,
  privacy,
  spam,
  other;

  static AnnouncementReportReason fromJson(String value) => switch (value) {
    'bullying' => AnnouncementReportReason.bullying,
    'inappropriate' => AnnouncementReportReason.inappropriate,
    'privacy' => AnnouncementReportReason.privacy,
    'spam' => AnnouncementReportReason.spam,
    _ => AnnouncementReportReason.other,
  };

  String toJson() => name;

  String get label => switch (this) {
    AnnouncementReportReason.bullying => 'Beleidigung oder Mobbing',
    AnnouncementReportReason.inappropriate => 'Unangemessener Inhalt',
    AnnouncementReportReason.privacy => 'Datenschutz oder persönliche Daten',
    AnnouncementReportReason.spam => 'Spam oder sachfremder Inhalt',
    AnnouncementReportReason.other => 'Anderer Grund',
  };
}

enum AnnouncementModerationAction {
  dismiss,
  remove,
  removeAndDeactivate;

  String toJson() => switch (this) {
    AnnouncementModerationAction.dismiss => 'dismiss',
    AnnouncementModerationAction.remove => 'remove',
    AnnouncementModerationAction.removeAndDeactivate => 'remove_and_deactivate',
  };
}

class AnnouncementReport {
  const AnnouncementReport({
    required this.id,
    required this.announcementId,
    required this.reason,
    this.details,
    required this.status,
    this.resolutionAction,
    required this.createdAt,
    this.resolvedAt,
    required this.reporterName,
    required this.senderUserId,
    required this.senderName,
    required this.senderRole,
    required this.senderStatus,
    required this.message,
    required this.announcementCreatedAt,
    required this.isModerated,
    required this.attachmentCount,
    required this.availableAttachmentCount,
  });

  final int id;
  final int announcementId;
  final AnnouncementReportReason reason;
  final String? details;
  final String status;
  final String? resolutionAction;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String reporterName;
  final int senderUserId;
  final String senderName;
  final String senderRole;
  final String senderStatus;
  final String message;
  final DateTime announcementCreatedAt;
  final bool isModerated;
  final int attachmentCount;
  final int availableAttachmentCount;

  bool get isOpen => status == 'open';

  String get statusLabel => switch (status) {
    'resolved' => 'Inhalt entfernt',
    'dismissed' => 'Als unbedenklich geschlossen',
    _ => 'Offen',
  };

  factory AnnouncementReport.fromJson(Map<String, dynamic> json) {
    DateTime? optionalDate(dynamic value) {
      if (value is! String || value.isEmpty) return null;
      return parseUtcDateTime(value);
    }

    return AnnouncementReport(
      id: (json['id'] as num).toInt(),
      announcementId: (json['announcement_id'] as num).toInt(),
      reason: AnnouncementReportReason.fromJson(
        (json['reason'] ?? 'other') as String,
      ),
      details: json['details'] as String?,
      status: (json['status'] ?? 'open') as String,
      resolutionAction: json['resolution_action'] as String?,
      createdAt: parseUtcDateTime(json['created_at'] as String),
      resolvedAt: optionalDate(json['resolved_at']),
      reporterName: (json['reporter_name'] ?? '') as String,
      senderUserId: (json['sender_user_id'] as num).toInt(),
      senderName: (json['sender_name'] ?? '') as String,
      senderRole: (json['sender_role'] ?? '') as String,
      senderStatus: (json['sender_status'] ?? 'active') as String,
      message: (json['message'] ?? '') as String,
      announcementCreatedAt: parseUtcDateTime(
        json['announcement_created_at'] as String,
      ),
      isModerated: json['is_moderated'] == true || json['is_moderated'] == 1,
      attachmentCount: ((json['attachment_count'] ?? 0) as num).toInt(),
      availableAttachmentCount:
          ((json['available_attachment_count'] ?? 0) as num).toInt(),
    );
  }
}
