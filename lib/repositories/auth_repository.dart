// ignore_for_file: prefer_initializing_formals

import '../core/api/api_client.dart';
import '../core/device/device_info_service.dart';
import '../core/push/push_service.dart';
import '../core/security/session_storage.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient api,
    required SessionStorage sessionStorage,
    required DeviceInfoService deviceInfoService,
    required PushService pushService,
  }) : _api = api,
       _sessionStorage = sessionStorage,
       _deviceInfoService = deviceInfoService,
       _pushService = pushService;

  final ApiClient _api;
  final SessionStorage _sessionStorage;
  final DeviceInfoService _deviceInfoService;
  final PushService _pushService;

  Future<User?> bootstrap() async {
    final session = await _sessionStorage.read();
    if (session == null) return null;
    final data = await _api.get('auth/session') as Map<String, dynamic>;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _sessionStorage.saveUser(user);
    await updatePushToken();
    return user;
  }

  Future<User> login({
    required String identifier,
    required String password,
  }) async {
    final device = await _deviceInfoService.read();
    final firebaseToken = await _pushService.readToken();
    final body = {
      'identifier': identifier,
      'password': password,
      ...device.toJson(),
      'firebase_token': firebaseToken,
    };
    final data =
        await _api.post('auth/login', body: body) as Map<String, dynamic>;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _sessionStorage.save(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      user: user,
    );
    return user;
  }

  Future<void> updatePushToken() async {
    final firebaseToken = await _pushService.readToken();
    if (firebaseToken == null) return;
    await _api.post(
      'auth/device-token',
      body: {'firebase_token': firebaseToken},
    );
  }

  Future<User> changePassword({
    required String currentPassword,
    required String newPassword,
    required bool revokeOtherDevices,
  }) async {
    final data =
        await _api.post(
              'auth/password',
              body: {
                'current_password': currentPassword,
                'new_password': newPassword,
                'revoke_other_devices': revokeOtherDevices,
              },
            )
            as Map<String, dynamic>;
    final session = await _sessionStorage.read();
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    if (session != null) {
      await _sessionStorage.save(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        user: user,
      );
    }
    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post('auth/logout');
    } finally {
      await _sessionStorage.clear();
    }
  }

  Future<void> clearLocalSession() => _sessionStorage.clear();
}
