import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/device/device_info_service.dart';
import '../core/push/push_service.dart';
import '../core/security/session_storage.dart';
import '../repositories/announcement_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/duty_repository.dart';
import '../repositories/user_repository.dart';

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SessionStorage(),
);
final deviceInfoServiceProvider = Provider<DeviceInfoService>(
  (ref) => DeviceInfoService(),
);
final pushServiceProvider = Provider<PushService>((ref) => PushService());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(sessionStorage: ref.watch(sessionStorageProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(apiClientProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
    deviceInfoService: ref.watch(deviceInfoServiceProvider),
    pushService: ref.watch(pushServiceProvider),
  );
});

final dutyRepositoryProvider = Provider<DutyRepository>((ref) {
  return DutyRepository(ref.watch(apiClientProvider));
});

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(ref.watch(apiClientProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(apiClientProvider));
});
