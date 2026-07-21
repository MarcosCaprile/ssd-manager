class Announcement {
  const Announcement({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });

  final int id;
  final int senderUserId;
  final String senderName;
  final String senderRole;
  final String message;
  final DateTime createdAt;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: (json['id'] as num).toInt(),
      senderUserId: (json['sender_user_id'] as num).toInt(),
      senderName: (json['sender_name'] ?? '') as String,
      senderRole: (json['sender_role'] ?? '') as String,
      message: (json['message'] ?? '') as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
