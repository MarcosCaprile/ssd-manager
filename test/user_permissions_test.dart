import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/models/user.dart';

void main() {
  const teacher = User(
    id: 1,
    firstName: 'Test',
    lastName: 'Teacher',
    username: 'teacher',
    email: 'teacher@example.test',
    role: UserRole.teacher,
    status: 'active',
    mustChangePassword: false,
  );
  const otherUser = User(
    id: 2,
    firstName: 'Test',
    lastName: 'Student',
    username: 'student',
    email: 'student@example.test',
    role: UserRole.sanitaeter,
    status: 'active',
    mustChangePassword: false,
  );
  const lead = User(
    id: 3,
    firstName: 'Test',
    lastName: 'Leitung',
    username: 'leitung',
    email: 'leitung@example.test',
    role: UserRole.saniLeitung,
    status: 'active',
    mustChangePassword: false,
  );
  const secretariat = User(
    id: 4,
    firstName: 'Test',
    lastName: 'Sekretariat',
    username: 'sekretariat',
    email: 'sekretariat@example.test',
    role: UserRole.sekretariat,
    status: 'active',
    mustChangePassword: false,
  );

  test('managers cannot administer their own account', () {
    expect(teacher.canManageAccount(teacher), isFalse);
    expect(teacher.canManageRoleOf(teacher), isFalse);
  });

  test('teachers can administer another account', () {
    expect(teacher.canManageAccount(otherUser), isTrue);
    expect(teacher.canManageRoleOf(otherUser), isTrue);
  });

  test('role changes are restricted to sanitary profiles', () {
    expect(teacher.canManageRoleOf(secretariat), isFalse);
    expect(lead.canManageRoleOf(otherUser), isTrue);
    expect(lead.canManageRoleOf(teacher), isFalse);
  });

  test('secretariat has read-only duty permissions', () {
    expect(secretariat.role.canAssignSelf, isFalse);
    expect(secretariat.role.canManageDuties, isFalse);
    expect(secretariat.role.canManageUsers, isFalse);
    expect(secretariat.role.hasDutyStatistics, isFalse);
  });

  test('sanitaeter-since date is parsed as a calendar date', () {
    final user = User.fromJson({
      'id': 5,
      'first_name': 'Sani',
      'last_name': 'Test',
      'username': 'sani',
      'email': 'sani@example.test',
      'role': 'sanitaeter',
      'sanitaeter_since': '2024-03-15',
      'status': 'active',
      'must_change_password': false,
    });

    expect(user.sanitaeterSince, DateTime(2024, 3, 15));
    expect(user.toJson()['sanitaeter_since'], '2024-03-15');
  });

  test('first-aiders are beginners for exactly their first 150 days', () {
    final sani = User(
      id: 6,
      firstName: 'Neu',
      lastName: 'Sani',
      username: 'neu.sani',
      email: 'neu.sani@example.test',
      role: UserRole.sanitaeter,
      sanitaeterSince: DateTime(2026, 1, 1),
      status: 'active',
      mustChangePassword: false,
    );

    expect(sani.isBeginnerSanitaeter(onDate: DateTime(2026, 1, 1)), isTrue);
    expect(sani.isBeginnerSanitaeter(onDate: DateTime(2026, 5, 30)), isTrue);
    expect(sani.isBeginnerSanitaeter(onDate: DateTime(2026, 5, 31)), isFalse);
    expect(lead.isBeginnerSanitaeter(onDate: DateTime(2026, 1, 2)), isFalse);
  });
}
