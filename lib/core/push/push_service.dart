import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'push_message_policy.dart';

const _announcementNotificationId = 41001;
const _notificationChannelId = 'ssd_manager_messages';
const _notificationChannelName = 'SSD Manager Nachrichten';
const _notificationThreadId = 'ssd-announcements';
const _sickNotificationChannelId = 'ssd_manager_sick_reports';
const _sickNotificationChannelName = 'SSD Manager Krankmeldungen';
const _sickNotificationThreadId = 'ssd-sick-reports';
const _storedAnnouncementLines = 'push.announcement_lines';
const _storedSickNotificationIds = 'push.sick_notification_ids';
const _storedAnnouncementUnreadCount = 'push.announcement_unread_count';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await _PushNotificationPresenter.show(
      message.data,
      announcementsVisible: false,
    );
  } catch (_) {
    // A missing native Firebase configuration must never crash app startup.
  }
}

class PushService {
  PushService();

  static bool _firebaseReady = false;
  static bool _listenersRegistered = false;
  static Future<void>? _initialization;
  static bool _announcementsVisible = false;
  static Map<String, dynamic>? _initialLocalData;
  static final _openedDataController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final _receivedDataController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final _tokenChangesController = StreamController<String>.broadcast();
  static const _settingsChannel = MethodChannel(
    'com.minutmate.ssdmanager/settings',
  );

  static Future<void> initializeFirebaseIfConfigured() async {
    if (_firebaseReady && _listenersRegistered) return;
    final activeInitialization = _initialization;
    if (activeInitialization != null) {
      await activeInitialization;
      return;
    }
    final initialization = _initialize();
    _initialization = initialization;
    try {
      await initialization;
    } finally {
      _initialization = null;
    }
  }

  static Future<void> _initialize() async {
    try {
      await _PushNotificationPresenter.initialize(
        onOpened: _openedDataController.add,
      );
      _initialLocalData ??= await _PushNotificationPresenter.initialData();
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      _firebaseReady = true;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
      if (_listenersRegistered) return;
      FirebaseMessaging.onMessage.listen((message) {
        final data = _combinedData(message);
        // In-app updates must never wait for the operating system's
        // notification UI. This is the actual realtime signal.
        _receivedDataController.add(data);
        unawaited(
          _PushNotificationPresenter.show(
            data,
            announcementsVisible: _announcementsVisible,
          ).catchError((_) {}),
        );
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _openedDataController.add(_combinedData(message));
      });
      FirebaseMessaging.instance.onTokenRefresh.listen(
        _tokenChangesController.add,
      );
      _listenersRegistered = true;
    } catch (_) {
      // A later login or foreground resume retries the complete setup.
      _firebaseReady = false;
    }
  }

  Future<String?> readToken() async {
    if (!_firebaseReady) {
      await initializeFirebaseIfConfigured();
    }
    if (!_firebaseReady) return null;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (!_firebaseReady) {
      await initializeFirebaseIfConfigured();
    }
    if (!_firebaseReady) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _settingsChannel.invokeMethod<void>('openNotificationSettings');
    } catch (_) {
      // Platforms without this channel keep the explanatory dialog as fallback.
    }
  }

  Stream<String> get tokenChanges => _tokenChangesController.stream;

  Stream<Map<String, dynamic>> get openedData => _openedDataController.stream;

  Stream<Map<String, dynamic>> get receivedData =>
      _receivedDataController.stream;

  Future<Map<String, dynamic>?> initialData() async {
    final localData = _initialLocalData;
    _initialLocalData = null;
    if (localData != null) return localData;
    if (!_firebaseReady) {
      await initializeFirebaseIfConfigured();
    }
    if (!_firebaseReady) return null;
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      return message == null ? null : _combinedData(message);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAnnouncementNotifications() =>
      _PushNotificationPresenter.clearAnnouncements();

  Future<int> announcementUnreadCount() =>
      _PushNotificationPresenter.announcementUnreadCount();

  void setAnnouncementsVisible(bool visible) {
    _announcementsVisible = visible;
  }

  static Map<String, dynamic> _combinedData(RemoteMessage message) {
    return <String, dynamic>{
      ...message.data,
      if (message.notification?.title != null)
        'title': message.notification!.title,
      if (message.notification?.body != null)
        'body': message.notification!.body,
    };
  }
}

class _PushNotificationPresenter {
  static const _operationTimeout = Duration(seconds: 5);
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Future<void> _operationQueue = Future.value();

  static Future<void> initialize({
    void Function(Map<String, dynamic> data)? onOpened,
  }) async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_ssd_manager'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final data = _decodePayload(response.payload);
        if (data != null) onOpened?.call(data);
      },
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _notificationChannelId,
        _notificationChannelName,
        description:
            'Ankündigungen und wichtige Nachrichten des Schulsanitätsdienstes',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _sickNotificationChannelId,
        _sickNotificationChannelName,
        description: 'Dringende Krankmeldungen aus dem Schulsanitätsdienst',
        importance: Importance.max,
      ),
    );
    _initialized = true;
  }

  static Future<Map<String, dynamic>?> initialData() async {
    if (!_initialized) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return _decodePayload(details?.notificationResponse?.payload);
  }

  static Future<void> show(
    Map<String, dynamic> data, {
    required bool announcementsVisible,
  }) {
    return _enqueue(
      () => _show(data, announcementsVisible: announcementsVisible),
    );
  }

  static Future<void> _show(
    Map<String, dynamic> data, {
    required bool announcementsVisible,
  }) async {
    await initialize();
    final title = (data['title'] ?? 'SSD Manager').toString().trim();
    final body = (data['body'] ?? '').toString().trim();
    if (body.isEmpty) return;

    final kind = PushMessagePolicy.classify(data);
    final payload = jsonEncode(data);
    final preferences = SharedPreferencesAsync();
    final unreadCount =
        PushMessagePolicy.countsAsUnread(
          kind: kind,
          announcementsVisible: announcementsVisible,
        )
        ? await _incrementAnnouncementUnreadCount(preferences)
        : await _readAnnouncementUnreadCount(preferences);

    if (kind == PushMessageKind.sickReport) {
      final notificationId = _sickNotificationId(data);
      final storedIds =
          await preferences.getStringList(_storedSickNotificationIds) ?? [];
      if (!storedIds.contains('$notificationId')) {
        await preferences.setStringList(_storedSickNotificationIds, [
          ...storedIds,
          '$notificationId',
        ]);
      }
      await _plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _sickNotificationChannelId,
            _sickNotificationChannelName,
            channelDescription:
                'Dringende Krankmeldungen aus dem Schulsanitätsdienst',
            icon: 'ic_stat_ssd_manager',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.message,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: DarwinNotificationDetails(
            threadIdentifier: _sickNotificationThreadId,
            badgeNumber: unreadCount > 0 ? unreadCount : null,
          ),
        ),
        payload: payload,
      );
      return;
    }

    if (kind == PushMessageKind.regularAnnouncement) {
      if (!PushMessagePolicy.shouldShowPhoneNotification(
        kind: kind,
        announcementsVisible: announcementsVisible,
      )) {
        return;
      }
      final previous =
          await preferences.getStringList(_storedAnnouncementLines) ?? [];
      final lines = [...previous, body];
      if (lines.length > 6) {
        lines.removeRange(0, lines.length - 6);
      }
      await preferences.setStringList(_storedAnnouncementLines, lines);
      final countText = lines.length == 1
          ? '1 neue Nachricht'
          : '${lines.length} neue Nachrichten';
      final style = InboxStyleInformation(
        lines,
        contentTitle: 'Ankündigungen',
        summaryText: countText,
      );
      await _plugin.show(
        id: _announcementNotificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _notificationChannelId,
            _notificationChannelName,
            channelDescription:
                'Ankündigungen und wichtige Nachrichten des Schulsanitätsdienstes',
            icon: 'ic_stat_ssd_manager',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            styleInformation: style,
            onlyAlertOnce: false,
          ),
          iOS: DarwinNotificationDetails(
            threadIdentifier: _notificationThreadId,
            badgeNumber: unreadCount > 0 ? unreadCount : null,
          ),
        ),
        payload: payload,
      );
      return;
    }

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannelId,
          _notificationChannelName,
          channelDescription:
              'Ankündigungen und wichtige Nachrichten des Schulsanitätsdienstes',
          icon: 'ic_stat_ssd_manager',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  static Future<void> clearAnnouncements() {
    return _enqueue(_clearAnnouncements);
  }

  static Future<void> _clearAnnouncements() async {
    await initialize();
    final preferences = SharedPreferencesAsync();
    final sickNotificationIds =
        await preferences.getStringList(_storedSickNotificationIds) ?? [];
    await preferences.remove(_storedAnnouncementLines);
    await preferences.remove(_storedSickNotificationIds);
    await preferences.setInt(_storedAnnouncementUnreadCount, 0);
    await _plugin.cancel(id: _announcementNotificationId);
    for (final value in sickNotificationIds) {
      final id = int.tryParse(value);
      if (id != null) {
        await _plugin.cancel(id: id);
      }
    }
  }

  static Future<int> announcementUnreadCount() {
    return _readAnnouncementUnreadCount(SharedPreferencesAsync());
  }

  static Future<int> _readAnnouncementUnreadCount(
    SharedPreferencesAsync preferences,
  ) async {
    return await preferences.getInt(_storedAnnouncementUnreadCount) ?? 0;
  }

  static Future<int> _incrementAnnouncementUnreadCount(
    SharedPreferencesAsync preferences,
  ) async {
    final current = await _readAnnouncementUnreadCount(preferences);
    final next = current + 1;
    await preferences.setInt(_storedAnnouncementUnreadCount, next);
    return next;
  }

  static int _sickNotificationId(Map<String, dynamic> data) {
    final announcementId = int.tryParse(
      (data['announcement_id'] ?? '').toString(),
    );
    final uniquePart =
        announcementId ??
        DateTime.now().millisecondsSinceEpoch.remainder(100000000);
    return 500000000 + uniquePart.remainder(100000000);
  }

  static Future<void> _enqueue(Future<void> Function() operation) {
    final queued = _operationQueue.then(
      (_) => operation().timeout(_operationTimeout),
    );
    _operationQueue = queued.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return queued;
  }

  static Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
