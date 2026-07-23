class AttachmentStorageSummary {
  const AttachmentStorageSummary({
    required this.usedBytes,
    required this.limitBytes,
    required this.attachments,
  });

  final int usedBytes;
  final int limitBytes;
  final List<StoredAttachment> attachments;

  double get usedFraction =>
      limitBytes <= 0 ? 0 : (usedBytes / limitBytes).clamp(0.0, 1.0).toDouble();

  factory AttachmentStorageSummary.fromJson(Map<String, dynamic> json) {
    return AttachmentStorageSummary(
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      limitBytes: (json['limit_bytes'] as num?)?.toInt() ?? 100 * 1024 * 1024,
      attachments: ((json['attachments'] as List<dynamic>?) ?? const [])
          .map(
            (item) => StoredAttachment.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class StoredAttachment {
  const StoredAttachment({
    required this.id,
    this.announcementId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.isImage,
    required this.createdAt,
  });

  final int id;
  final int? announcementId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final bool isImage;
  final DateTime createdAt;

  factory StoredAttachment.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['created_at'] ?? '').toString();
    final normalized = rawDate.contains('T')
        ? rawDate
        : rawDate.replaceFirst(' ', 'T');
    return StoredAttachment(
      id: (json['id'] as num).toInt(),
      announcementId: (json['announcement_id'] as num?)?.toInt(),
      fileName: (json['file_name'] ?? 'Datei') as String,
      mimeType: (json['mime_type'] ?? '') as String,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      isImage: json['is_image'] == true || json['is_image'] == 1,
      createdAt:
          DateTime.tryParse('${normalized}Z')?.toLocal() ?? DateTime.now(),
    );
  }
}
