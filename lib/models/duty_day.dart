import 'package:flutter/foundation.dart';

import '../utils/json_date_time.dart';

class DutyAssignment {
  const DutyAssignment({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.status,
    required this.assignmentType,
    required this.role,
    this.sanitaeterSince,
    this.assignedAt,
    this.sickReportedAt,
  });

  final int id;
  final int userId;
  final String fullName;
  final String status;
  final String assignmentType;
  final String role;
  final DateTime? sanitaeterSince;
  final DateTime? assignedAt;
  final DateTime? sickReportedAt;

  bool get occupiesSlot => status == 'planned' || status == 'completed';
  bool get isSick => status == 'sick_reported';
  bool isBeginnerSanitaeter({DateTime? onDate}) {
    if (role != 'sanitaeter' || sanitaeterSince == null) return false;
    final reference = onDate ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final start = DateTime(
      sanitaeterSince!.year,
      sanitaeterSince!.month,
      sanitaeterSince!.day,
    );
    return !today.isBefore(start) &&
        DateTime.utc(today.year, today.month, today.day)
                .difference(DateTime.utc(start.year, start.month, start.day))
                .inDays <
            150;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DutyAssignment &&
            id == other.id &&
            userId == other.userId &&
            fullName == other.fullName &&
            status == other.status &&
            assignmentType == other.assignmentType &&
            role == other.role &&
            sanitaeterSince == other.sanitaeterSince &&
            assignedAt == other.assignedAt &&
            sickReportedAt == other.sickReportedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    fullName,
    status,
    assignmentType,
    role,
    sanitaeterSince,
    assignedAt,
    sickReportedAt,
  );

  factory DutyAssignment.fromJson(Map<String, dynamic> json) {
    return DutyAssignment(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      fullName: (json['full_name'] ?? '') as String,
      status: (json['status'] ?? 'planned') as String,
      assignmentType: (json['assignment_type'] ?? 'self') as String,
      role: (json['role'] ?? 'sanitaeter') as String,
      sanitaeterSince: _dateFromJson(json['sanitaeter_since']),
      assignedAt: json['assigned_at'] == null
          ? null
          : parseUtcDateTime(json['assigned_at'] as String),
      sickReportedAt: json['sick_reported_at'] == null
          ? null
          : parseUtcDateTime(json['sick_reported_at'] as String),
    );
  }

  static DateTime? _dateFromJson(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    return DateTime(
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DutyDay &&
            date == other.date &&
            capacity == other.capacity &&
            isActive == other.isActive &&
            isClosed == other.isClosed &&
            title == other.title &&
            description == other.description &&
            listEquals(assignments, other.assignments);
  }

  @override
  int get hashCode => Object.hash(
    date,
    capacity,
    isActive,
    isClosed,
    title,
    description,
    Object.hashAll(assignments),
  );

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
