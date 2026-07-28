enum UserBulkAction {
  create,
  update,
  deactivate,
  reactivate,
  markDeletion;

  String get apiValue => switch (this) {
    UserBulkAction.create => 'create',
    UserBulkAction.update => 'update',
    UserBulkAction.deactivate => 'deactivate',
    UserBulkAction.reactivate => 'reactivate',
    UserBulkAction.markDeletion => 'mark_deletion',
  };

  String get label => switch (this) {
    UserBulkAction.create => 'Hinzufügen',
    UserBulkAction.update => 'Bearbeiten',
    UserBulkAction.deactivate => 'Deaktivieren',
    UserBulkAction.reactivate => 'Reaktivieren',
    UserBulkAction.markDeletion => 'Löschung vormerken',
  };

  String get spreadsheetValue => switch (this) {
    UserBulkAction.create => 'hinzufügen',
    UserBulkAction.update => 'bearbeiten',
    UserBulkAction.deactivate => 'deaktivieren',
    UserBulkAction.reactivate => 'reaktivieren',
    UserBulkAction.markDeletion => 'löschung_vormerken',
  };

  static UserBulkAction? fromSpreadsheet(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'hinzufügen' ||
      'hinzufuegen' ||
      'create' ||
      'add' => UserBulkAction.create,
      'bearbeiten' || 'update' || 'edit' => UserBulkAction.update,
      'deaktivieren' ||
      'entfernen' ||
      'deactivate' ||
      'remove' => UserBulkAction.deactivate,
      'reaktivieren' || 'reactivate' => UserBulkAction.reactivate,
      'löschung_vormerken' ||
      'loeschung_vormerken' ||
      'mark_deletion' ||
      'delete' => UserBulkAction.markDeletion,
      _ => null,
    };
  }

  static UserBulkAction? fromApi(String value) {
    return UserBulkAction.values
        .where((action) => action.apiValue == value)
        .firstOrNull;
  }
}

class UserBulkRow {
  const UserBulkRow({
    required this.rowNumber,
    required this.action,
    required this.rawAction,
    this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.temporaryPassword,
    required this.role,
    required this.sanitaeterSince,
    this.localErrors = const [],
  });

  final int rowNumber;
  final UserBulkAction? action;
  final String rawAction;
  final int? id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String temporaryPassword;
  final String role;
  final String sanitaeterSince;
  final List<String> localErrors;

  String get displayName {
    final name = '$firstName $lastName'.trim();
    if (name.isNotEmpty) return name;
    return id == null ? 'Unbekannte Person' : 'Account #$id';
  }

  String get startDateForDisplay {
    if (role != 'sanitaeter' && role != 'sani_leitung') return 'N/A';
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(sanitaeterSince);
    return match == null
        ? sanitaeterSince
        : '${match.group(3)}/${match.group(2)}/${match.group(1)}';
  }

  UserBulkRow copyWith({
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    String? temporaryPassword,
    String? role,
    String? sanitaeterSince,
    List<String>? localErrors,
  }) {
    return UserBulkRow(
      rowNumber: rowNumber,
      action: action,
      rawAction: rawAction,
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      email: email ?? this.email,
      temporaryPassword: temporaryPassword ?? this.temporaryPassword,
      role: role ?? this.role,
      sanitaeterSince: sanitaeterSince ?? this.sanitaeterSince,
      localErrors: localErrors ?? this.localErrors,
    );
  }

  Map<String, dynamic> toJson() => {
    'row_number': rowNumber,
    'action': action?.apiValue ?? rawAction,
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'username': username,
    'email': email,
    'temporary_password': temporaryPassword,
    'role': role,
    'sanitaeter_since': sanitaeterSince,
  };
}

class UserBulkValidationRow {
  const UserBulkValidationRow({
    required this.rowNumber,
    required this.action,
    required this.targetUserId,
    required this.displayName,
    required this.valid,
    required this.errors,
  });

  final int rowNumber;
  final UserBulkAction? action;
  final int? targetUserId;
  final String displayName;
  final bool valid;
  final List<String> errors;

  factory UserBulkValidationRow.fromJson(Map<String, dynamic> json) {
    return UserBulkValidationRow(
      rowNumber: (json['row_number'] as num?)?.toInt() ?? 0,
      action: UserBulkAction.fromApi((json['action'] ?? '') as String),
      targetUserId: (json['target_user_id'] as num?)?.toInt(),
      displayName: (json['display_name'] ?? '') as String,
      valid: json['valid'] == true,
      errors: (json['errors'] as List<dynamic>? ?? const [])
          .map((error) => error.toString())
          .toList(),
    );
  }
}

class UserBulkValidation {
  const UserBulkValidation({
    required this.valid,
    required this.rows,
    this.applied = false,
    this.appliedCount = 0,
  });

  final bool valid;
  final bool applied;
  final int appliedCount;
  final List<UserBulkValidationRow> rows;

  factory UserBulkValidation.fromJson(Map<String, dynamic> json) {
    return UserBulkValidation(
      valid: json['valid'] == true,
      applied: json['applied'] == true,
      appliedCount: (json['applied_count'] as num?)?.toInt() ?? 0,
      rows: (json['rows'] as List<dynamic>? ?? const [])
          .map(
            (row) =>
                UserBulkValidationRow.fromJson(row as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
