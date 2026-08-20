import 'package:flutter/foundation.dart';

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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AnnouncementAttachment &&
            id == other.id &&
            fileName == other.fileName &&
            mimeType == other.mimeType &&
            sizeBytes == other.sizeBytes &&
            isImage == other.isImage &&
            isDeleted == other.isDeleted;
  }

  @override
  int get hashCode =>
      Object.hash(id, fileName, mimeType, sizeBytes, isImage, isDeleted);

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

  AnnouncementAttachment copyWith({bool? isDeleted}) {
    return AnnouncementAttachment(
      id: id,
      fileName: fileName,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      isImage: isImage,
      isDeleted: isDeleted ?? this.isDeleted,
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
    required this.messageType,
    this.systemType,
    this.isModerated = false,
    this.reportedByMe = false,
    required this.createdAt,
    required this.attachments,
  });

  final int id;
  final int senderUserId;
  final String senderName;
  final String senderRole;
  final String message;
  final String messageType;
  final String? systemType;
  final bool isModerated;
  final bool reportedByMe;
  final DateTime createdAt;
  final List<AnnouncementAttachment> attachments;

  bool get isSystem => messageType == 'system';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Announcement &&
            id == other.id &&
            senderUserId == other.senderUserId &&
            senderName == other.senderName &&
            senderRole == other.senderRole &&
            message == other.message &&
            messageType == other.messageType &&
            systemType == other.systemType &&
            isModerated == other.isModerated &&
            reportedByMe == other.reportedByMe &&
            createdAt == other.createdAt &&
            listEquals(attachments, other.attachments);
  }

  @override
  int get hashCode => Object.hash(
    id,
    senderUserId,
    senderName,
    senderRole,
    message,
    messageType,
    systemType,
    isModerated,
    reportedByMe,
    createdAt,
    Object.hashAll(attachments),
  );

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: (json['id'] as num).toInt(),
      senderUserId: (json['sender_user_id'] as num).toInt(),
      senderName: (json['sender_name'] ?? '') as String,
      senderRole: (json['sender_role'] ?? '') as String,
      message: (json['message'] ?? '') as String,
      messageType: (json['message_type'] ?? 'user') as String,
      systemType: json['system_type'] as String?,
      isModerated: json['is_moderated'] == true || json['is_moderated'] == 1,
      reportedByMe:
          json['reported_by_me'] == true || json['reported_by_me'] == 1,
      createdAt: parseUtcDateTime(json['created_at'] as String),
      attachments: ((json['attachments'] ?? []) as List<dynamic>)
          .map(
            (item) =>
                AnnouncementAttachment.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Announcement copyWith({
    String? message,
    bool? isModerated,
    bool? reportedByMe,
    List<AnnouncementAttachment>? attachments,
  }) {
    return Announcement(
      id: id,
      senderUserId: senderUserId,
      senderName: senderName,
      senderRole: senderRole,
      message: message ?? this.message,
      messageType: messageType,
      systemType: systemType,
      isModerated: isModerated ?? this.isModerated,
      reportedByMe: reportedByMe ?? this.reportedByMe,
      createdAt: createdAt,
      attachments: attachments ?? this.attachments,
    );
  }
}
