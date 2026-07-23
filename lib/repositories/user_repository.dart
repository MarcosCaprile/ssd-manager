import '../core/api/api_client.dart';
import '../models/device_session.dart';
import '../models/attachment_storage.dart';
import '../models/profile_statistics.dart';
import '../models/user.dart';
import '../models/user_bulk.dart';

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

  Future<AttachmentStorageSummary> attachmentStorage({
    String sort = 'date_desc',
  }) async {
    final data =
        await _api.get('me/attachments', query: {'sort': sort})
            as Map<String, dynamic>;
    return AttachmentStorageSummary.fromJson(data);
  }

  Future<void> deleteAttachment(int id) => _api.delete('me/attachments/$id');

  Future<List<DeviceSession>> devices() async {
    final data = await _api.get('me/devices') as List<dynamic>;
    return data
        .map((item) => DeviceSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> revokeDevice(int deviceId) =>
      _api.delete('me/devices/$deviceId');
  Future<void> revokeOtherDevices() => _api.delete('me/devices');

  Future<List<User>> users() async {
    final data = await _api.get('users') as List<dynamic>;
    return data
        .map((item) => User.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<({User user, ProfileStatistics? statistics})> userProfile(
    int id,
  ) async {
    final data = await _api.get('users/$id') as Map<String, dynamic>;
    final statistics = data['statistics'];
    return (
      user: User.fromJson(data['user'] as Map<String, dynamic>),
      statistics: statistics is Map<String, dynamic>
          ? ProfileStatistics.fromJson(statistics)
          : null,
    );
  }

  Future<void> createUser({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String temporaryPassword,
    required String role,
    DateTime? sanitaeterSince,
  }) {
    return _api.post(
      'users',
      body: {
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'email': email,
        'temporary_password': temporaryPassword,
        'role': role,
        'sanitaeter_since': sanitaeterSince == null
            ? null
            : '${sanitaeterSince.year.toString().padLeft(4, '0')}-'
                  '${sanitaeterSince.month.toString().padLeft(2, '0')}-'
                  '${sanitaeterSince.day.toString().padLeft(2, '0')}',
      },
    );
  }

  Future<void> deactivate(int id) => _api.post('users/$id/deactivate');
  Future<void> reactivate(int id) => _api.post('users/$id/reactivate');
  Future<void> markDeletion(int id) => _api.post('users/$id/mark-deletion');

  Future<void> changeRole(int id, UserRole role) {
    return _api.patch('users/$id/role', body: {'role': role.toJson()});
  }

  Future<UserBulkValidation> validateBulk(List<UserBulkRow> rows) async {
    final data =
        await _api.post(
              'users/bulk/validate',
              body: {'rows': rows.map((row) => row.toJson()).toList()},
            )
            as Map<String, dynamic>;
    return UserBulkValidation.fromJson(data);
  }

  Future<UserBulkValidation> applyBulk(List<UserBulkRow> rows) async {
    final data =
        await _api.post(
              'users/bulk/apply',
              body: {'rows': rows.map((row) => row.toJson()).toList()},
            )
            as Map<String, dynamic>;
    return UserBulkValidation.fromJson(data);
  }
}
