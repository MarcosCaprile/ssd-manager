import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/device/device_info_service.dart';
import '../core/files/bulk_user_spreadsheet_service.dart';
import '../core/push/push_service.dart';
import '../core/security/session_storage.dart';
import '../models/announcement.dart';
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
final bulkUserSpreadsheetServiceProvider = Provider<BulkUserSpreadsheetService>(
  (ref) => BulkUserSpreadsheetService(),
);

class DataRevisionController extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

class AnnouncementUnreadController extends Notifier<int> {
  @override
  int build() => 0;

  void setCount(int count) {
    state = count < 0 ? 0 : count;
  }

  void ensureAtLeast(int count) {
    if (count > state) state = count;
  }

  Future<void> clear() async {
    state = 0;
    try {
      await ref.read(pushServiceProvider).clearAnnouncementNotifications();
    } catch (_) {
      // The in-app read state stays valid if platform notification cleanup
      // is temporarily unavailable.
    }
  }
}

final userRevisionProvider = NotifierProvider<DataRevisionController, int>(
  DataRevisionController.new,
);
final dutyRevisionProvider = NotifierProvider<DataRevisionController, int>(
  DataRevisionController.new,
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    sessionStorage: ref.watch(sessionStorageProvider),
    onMutationSucceeded: (method, path) {
      if (path == 'users' || path.startsWith('users/')) {
        ref.read(userRevisionProvider.notifier).bump();
        ref.read(dutyRevisionProvider.notifier).bump();
      }
      if (path == 'duties' || path.startsWith('duties/')) {
        ref.read(dutyRevisionProvider.notifier).bump();
        ref.read(userRevisionProvider.notifier).bump();
      }
      if (path == 'announcements' ||
          path.startsWith('announcements/') ||
          path.startsWith('me/attachments')) {
        ref.read(announcementRevisionProvider.notifier).bump();
      }
    },
  );
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

final announcementRevisionProvider =
    NotifierProvider<DataRevisionController, int>(DataRevisionController.new);

final announcementUnreadProvider =
    NotifierProvider<AnnouncementUnreadController, int>(
      AnnouncementUnreadController.new,
    );

class AnnouncementFeedController extends Notifier<List<Announcement>?> {
  @override
  List<Announcement>? build() => null;

  void replace(List<Announcement> announcements) {
    if (listEquals(state, announcements)) return;
    state = List.unmodifiable(announcements);
  }
}

final announcementFeedProvider =
    NotifierProvider<AnnouncementFeedController, List<Announcement>?>(
      AnnouncementFeedController.new,
    );

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(apiClientProvider));
});
