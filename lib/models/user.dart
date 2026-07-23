enum UserRole {
  sanitaeter,
  saniLeitung,
  teacher,
  sekretariat;

  static UserRole fromJson(String value) => switch (value) {
    'sani_leitung' => UserRole.saniLeitung,
    'teacher' => UserRole.teacher,
    'sekretariat' => UserRole.sekretariat,
    _ => UserRole.sanitaeter,
  };

  String toJson() => switch (this) {
    UserRole.sanitaeter => 'sanitaeter',
    UserRole.saniLeitung => 'sani_leitung',
    UserRole.teacher => 'teacher',
    UserRole.sekretariat => 'sekretariat',
  };

  String get label => switch (this) {
    UserRole.sanitaeter => 'Schulsanitaeter',
    UserRole.saniLeitung => 'Sani-Leitung',
    UserRole.teacher => 'Lehreraufsicht',
    UserRole.sekretariat => 'Sekretariat',
  };

  bool get canManageUsers =>
      this == UserRole.saniLeitung || this == UserRole.teacher;
  bool get canManageDuties =>
      this == UserRole.saniLeitung || this == UserRole.teacher;
  bool get canAssignSelf =>
      this == UserRole.sanitaeter || this == UserRole.saniLeitung;
  bool get canManageRoles =>
      this == UserRole.saniLeitung || this == UserRole.teacher;
  bool get isSanitaryRole =>
      this == UserRole.sanitaeter || this == UserRole.saniLeitung;
  bool get hasDutyStatistics => isSanitaryRole;
}

class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.role,
    this.sanitaeterSince,
    required this.status,
    required this.mustChangePassword,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final UserRole role;
  final DateTime? sanitaeterSince;
  final String status;
  final bool mustChangePassword;

  String get fullName => '$firstName $lastName'.trim();
  bool get isActive => status == 'active';
  bool canManageAccount(User target) => role.canManageUsers && id != target.id;
  bool canManageRoleOf(User target) =>
      role.canManageRoles && id != target.id && target.role.isSanitaryRole;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      firstName: (json['first_name'] ?? '') as String,
      lastName: (json['last_name'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      role: UserRole.fromJson((json['role'] ?? 'sanitaeter') as String),
      sanitaeterSince: _dateFromJson(json['sanitaeter_since']),
      status: (json['status'] ?? 'inactive') as String,
      mustChangePassword:
          json['must_change_password'] == true ||
          json['must_change_password'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'username': username,
    'email': email,
    'role': role.toJson(),
    'sanitaeter_since': sanitaeterSince == null
        ? null
        : '${sanitaeterSince!.year.toString().padLeft(4, '0')}-'
              '${sanitaeterSince!.month.toString().padLeft(2, '0')}-'
              '${sanitaeterSince!.day.toString().padLeft(2, '0')}',
    'status': status,
    'must_change_password': mustChangePassword,
  };

  User copyWith({
    bool? mustChangePassword,
    String? status,
    UserRole? role,
    DateTime? sanitaeterSince,
  }) {
    return User(
      id: id,
      firstName: firstName,
      lastName: lastName,
      username: username,
      email: email,
      role: role ?? this.role,
      sanitaeterSince: sanitaeterSince ?? this.sanitaeterSince,
      status: status ?? this.status,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
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
