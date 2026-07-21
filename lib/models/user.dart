enum UserRole {
  sanitaeter,
  saniLeitung,
  teacher;

  static UserRole fromJson(String value) => switch (value) {
        'sani_leitung' => UserRole.saniLeitung,
        'teacher' => UserRole.teacher,
        _ => UserRole.sanitaeter,
      };

  String toJson() => switch (this) {
        UserRole.sanitaeter => 'sanitaeter',
        UserRole.saniLeitung => 'sani_leitung',
        UserRole.teacher => 'teacher',
      };

  String get label => switch (this) {
        UserRole.sanitaeter => 'Schulsanitaeter',
        UserRole.saniLeitung => 'Sani-Leitung',
        UserRole.teacher => 'Lehreraufsicht',
      };

  bool get canManageUsers => this == UserRole.saniLeitung || this == UserRole.teacher;
  bool get canManageDuties => this == UserRole.saniLeitung || this == UserRole.teacher;
  bool get canAssignSelf => this != UserRole.teacher;
  bool get canManageRoles => this == UserRole.teacher;
}

class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.role,
    required this.status,
    required this.mustChangePassword,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final UserRole role;
  final String status;
  final bool mustChangePassword;

  String get fullName => '$firstName $lastName'.trim();
  bool get isActive => status == 'active';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      firstName: (json['first_name'] ?? '') as String,
      lastName: (json['last_name'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      role: UserRole.fromJson((json['role'] ?? 'sanitaeter') as String),
      status: (json['status'] ?? 'inactive') as String,
      mustChangePassword: json['must_change_password'] == true || json['must_change_password'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'email': email,
        'role': role.toJson(),
        'status': status,
        'must_change_password': mustChangePassword,
      };

  User copyWith({bool? mustChangePassword, String? status, UserRole? role}) {
    return User(
      id: id,
      firstName: firstName,
      lastName: lastName,
      username: username,
      email: email,
      role: role ?? this.role,
      status: status ?? this.status,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }
}
