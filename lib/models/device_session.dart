import '../utils/json_date_time.dart';

class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.deviceModel,
    required this.appVersion,
    required this.createdAt,
    required this.lastActiveAt,
    required this.isCurrent,
  });

  final int id;
  final String deviceName;
  final String platform;
  final String deviceModel;
  final String appVersion;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isCurrent;

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      id: (json['id'] as num).toInt(),
      deviceName: (json['device_name'] ?? 'Unbekanntes Geraet') as String,
      platform: (json['platform'] ?? '') as String,
      deviceModel: (json['device_model'] ?? '') as String,
      appVersion: (json['app_version'] ?? '') as String,
      createdAt: parseUtcDateTime(json['created_at'] as String),
      lastActiveAt: parseUtcDateTime(json['last_active_at'] as String),
      isCurrent: json['is_current'] == true || json['is_current'] == 1,
    );
  }
}
