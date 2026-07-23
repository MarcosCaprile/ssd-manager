import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceContext {
  const DeviceContext({
    required this.deviceName,
    required this.platform,
    required this.deviceModel,
    required this.appVersion,
    required this.installId,
  });

  final String deviceName;
  final String platform;
  final String deviceModel;
  final String appVersion;
  final String installId;

  Map<String, dynamic> toJson() => {
    'device_name': deviceName,
    'platform': platform,
    'device_model': deviceModel,
    'app_version': appVersion,
    'device_install_id': installId,
  };
}

class DeviceInfoService {
  DeviceInfoService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _installIdKey = 'ssd_device_install_id';

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final FlutterSecureStorage _storage;

  Future<DeviceContext> read() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final installId = await _readOrCreateInstallId();

    if (Platform.isAndroid) {
      final android = await _deviceInfo.androidInfo;
      return DeviceContext(
        deviceName: android.name,
        platform: 'android',
        deviceModel: '${android.manufacturer} ${android.model}'.trim(),
        appVersion: appVersion,
        installId: installId,
      );
    }

    if (Platform.isIOS) {
      final ios = await _deviceInfo.iosInfo;
      return DeviceContext(
        deviceName: ios.name,
        platform: 'ios',
        deviceModel: ios.utsname.machine,
        appVersion: appVersion,
        installId: installId,
      );
    }

    return DeviceContext(
      deviceName: Platform.localHostname,
      platform: Platform.operatingSystem,
      deviceModel: Platform.operatingSystemVersion,
      appVersion: appVersion,
      installId: installId,
    );
  }

  Future<String> _readOrCreateInstallId() async {
    final existing = await _storage.read(key: _installIdKey);
    if (existing != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final value = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _installIdKey, value: value);
    return value;
  }
}
