import '../utils/json_date_time.dart';

class AnnouncementAttachment {
  const AnnouncementAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.isImage,
    required this.isDeleted,
  });

  final int id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final bool isImage;
  final bool isDeleted;

  factory AnnouncementAttachment.fromJson(Map<String, dynamic> json) {
    return AnnouncementAttachment(
      id: (json['id'] as num).toInt(),
      fileName: (json['file_name'] ?? 'Datei') as String,
      mimeType: (json['mime_type'] ?? 'application/octet-stream') as String,
      sizeBytes: ((json['size_bytes'] ?? 0) as num).toInt(),
      isImage: json['is_image'] == true || json['is_image'] == 1,
      isDeleted: json['is_deleted'] == true || json['is_deleted'] == 1,
    );
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.createdAt,
    required this.attachments,
  });

  final int id;
  final int senderUserId;
  final String senderName;
  final String senderRole;
  final String message;
  final DateTime createdAt;
  final List<AnnouncementAttachment> attachments;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: (json['id'] as num).toInt(),
      senderUserId: (json['sender_user_id'] as num).toInt(),
      senderName: (json['sender_name'] ?? '') as String,
      senderRole: (json['sender_role'] ?? '') as String,
      message: (json['message'] ?? '') as String,
      createdAt: parseUtcDateTime(json['created_at'] as String),
      attachments: ((json['attachments'] ?? []) as List<dynamic>)
          .map(
            (item) =>
                AnnouncementAttachment.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
