import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceContext {
  const DeviceContext({
    required this.deviceName,
    required this.platform,
    required this.deviceModel,
    required this.appVersion,
  });

  final String deviceName;
  final String platform;
  final String deviceModel;
  final String appVersion;

  Map<String, dynamic> toJson() => {
        'device_name': deviceName,
        'platform': platform,
        'device_model': deviceModel,
        'app_version': appVersion,
      };
}

class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<DeviceContext> read() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    if (Platform.isAndroid) {
      final android = await _deviceInfo.androidInfo;
      return DeviceContext(
        deviceName: android.name,
        platform: 'android',
        deviceModel: '${android.manufacturer} ${android.model}'.trim(),
        appVersion: appVersion,
      );
    }

    if (Platform.isIOS) {
      final ios = await _deviceInfo.iosInfo;
      return DeviceContext(
        deviceName: ios.name,
        platform: 'ios',
        deviceModel: ios.utsname.machine,
        appVersion: appVersion,
      );
    }

    return DeviceContext(
      deviceName: Platform.localHostname,
      platform: Platform.operatingSystem,
      deviceModel: Platform.operatingSystemVersion,
      appVersion: appVersion,
    );
  }
}
