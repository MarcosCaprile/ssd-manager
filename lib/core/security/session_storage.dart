import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/user.dart';

class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final User user;
}

class SessionStorage {
  SessionStorage({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'ssd_access_token';
  static const _refreshTokenKey = 'ssd_refresh_token';
  static const _userKey = 'ssd_user';

  Future<StoredSession?> read() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final userJson = await _storage.read(key: _userKey);
    if (accessToken == null || refreshToken == null || userJson == null) {
      return null;
    }
    return StoredSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: User.fromJson(jsonDecode(userJson) as Map<String, dynamic>),
    );
  }

  Future<String?> accessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> refreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required User user,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<void> saveUser(User user) async {
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<void> clear() => _storage.deleteAll();
}
