import '../core/api/api_client.dart';
import '../models/device_session.dart';
import '../models/profile_statistics.dart';
import '../models/user.dart';

class UserRepository {
  UserRepository(this._api);

  final ApiClient _api;

  Future<User> me() async {
    final data = await _api.get('me') as Map<String, dynamic>;
    return User.fromJson(data);
  }

  Future<ProfileStatistics> myStatistics() async {
    final data = await _api.get('me/statistics') as Map<String, dynamic>;
    return ProfileStatistics.fromJson(data);
  }

  Future<List<DeviceSession>> devices() async {
    final data = await _api.get('me/devices') as List<dynamic>;
    return data.map((item) => DeviceSession.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> revokeDevice(int deviceId) => _api.delete('me/devices/$deviceId');
  Future<void> revokeOtherDevices() => _api.delete('me/devices');

  Future<List<User>> users() async {
    final data = await _api.get('users') as List<dynamic>;
    return data.map((item) => User.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<User> userDetails(int id) async {
    final data = await _api.get('users/$id') as Map<String, dynamic>;
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<ProfileStatistics> userStatistics(int id) async {
    final data = await _api.get('users/$id') as Map<String, dynamic>;
    return ProfileStatistics.fromJson(data['statistics'] as Map<String, dynamic>);
  }

  Future<void> createUser({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String temporaryPassword,
    required String role,
  }) {
    return _api.post('users', body: {
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'email': email,
      'temporary_password': temporaryPassword,
      'role': role,
    });
  }

  Future<void> deactivate(int id) => _api.post('users/$id/deactivate');
  Future<void> reactivate(int id) => _api.post('users/$id/reactivate');
  Future<void> markDeletion(int id) => _api.post('users/$id/mark-deletion');

  Future<void> changeRole(int id, UserRole role) {
    return _api.patch('users/$id/role', body: {'role': role.toJson()});
  }
}
