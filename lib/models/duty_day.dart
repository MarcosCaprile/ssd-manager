import '../utils/json_date_time.dart';

class DutyAssignment {
  const DutyAssignment({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.status,
    required this.assignmentType,
    this.assignedAt,
    this.sickReportedAt,
  });

  final int id;
  final int userId;
  final String fullName;
  final String status;
  final String assignmentType;
  final DateTime? assignedAt;
  final DateTime? sickReportedAt;

  bool get occupiesSlot => status == 'planned' || status == 'completed';
  bool get isSick => status == 'sick_reported';

  factory DutyAssignment.fromJson(Map<String, dynamic> json) {
    return DutyAssignment(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      fullName: (json['full_name'] ?? '') as String,
      status: (json['status'] ?? 'planned') as String,
      assignmentType: (json['assignment_type'] ?? 'self') as String,
      assignedAt: json['assigned_at'] == null
          ? null
          : parseUtcDateTime(json['assigned_at'] as String),
      sickReportedAt: json['sick_reported_at'] == null
          ? null
          : parseUtcDateTime(json['sick_reported_at'] as String),
    );
  }
}

class DutyDay {
  const DutyDay({
    required this.date,
    required this.capacity,
    required this.isActive,
    required this.isClosed,
    required this.assignments,
    this.title,
    this.description,
  });

  final DateTime date;
  final int capacity;
  final bool isActive;
  final bool isClosed;
  final String? title;
  final String? description;
  final List<DutyAssignment> assignments;

  int get occupiedSlots =>
      assignments.where((item) => item.occupiesSlot).length;
  int get freeSlots => capacity - occupiedSlots;
  bool get isFull => occupiedSlots >= capacity;

  DutyAssignment? assignmentForUser(int userId) {
    for (final assignment in assignments) {
      if (assignment.userId == userId && assignment.status == 'planned') {
        return assignment;
      }
    }
    return null;
  }

  factory DutyDay.fromJson(Map<String, dynamic> json) {
    return DutyDay(
      date: DateTime.parse(json['date'] as String),
      capacity: ((json['capacity'] ?? 3) as num).toInt(),
      isActive: json['is_active'] != false && json['is_active'] != 0,
      isClosed: json['is_closed'] == true || json['is_closed'] == 1,
      title: _optionalText(json['title']),
      description: _optionalText(json['description']),
      assignments: ((json['assignments'] ?? []) as List<dynamic>)
          .map((item) => DutyAssignment.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  static String? _optionalText(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
