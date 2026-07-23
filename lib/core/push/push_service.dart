import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _announcementNotificationId = 41001;
const _notificationChannelId = 'ssd_manager_messages';
const _notificationChannelName = 'SSD Manager Nachrichten';
const _notificationThreadId = 'ssd-announcements';
const _storedAnnouncementLines = 'push.announcement_lines';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await _PushNotificationPresenter.show(message.data);
  } catch (_) {
    // A missing native Firebase configuration must never crash app startup.
  }
}

class PushService {
  PushService();

  static bool _firebaseReady = false;
  static bool _listenersRegistered = false;
  static Map<String, dynamic>? _initialLocalData;
  static final _openedDataController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final _receivedDataController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Future<void> initializeFirebaseIfConfigured() async {
    await _PushNotificationPresenter.initialize(
      onOpened: _openedDataController.add,
    );
    _initialLocalData = await _PushNotificationPresenter.initialData();

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
      if (!_listenersRegistered) {
        FirebaseMessaging.onMessage.listen((message) async {
          final data = _combinedData(message);
          _receivedDataController.add(data);
          await _PushNotificationPresenter.show(data);
        });
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _openedDataController.add(_combinedData(message));
        });
        _listenersRegistered = true;
      }
    } catch (_) {
      _firebaseReady = false;
    }
  }

  Future<String?> readToken() async {
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

  Stream<String> get tokenChanges {
    if (!_firebaseReady) return const Stream.empty();
    return FirebaseMessaging.instance.onTokenRefresh;
  }

  Stream<Map<String, dynamic>> get openedData => _openedDataController.stream;

  Stream<Map<String, dynamic>> get receivedData =>
      _receivedDataController.stream;

  Future<Map<String, dynamic>?> initialData() async {
    final localData = _initialLocalData;
    _initialLocalData = null;
    if (localData != null) return localData;
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
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

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
    _initialized = true;
  }

  static Future<Map<String, dynamic>?> initialData() async {
    if (!_initialized) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return _decodePayload(details?.notificationResponse?.payload);
  }

  static Future<void> show(Map<String, dynamic> data) async {
    await initialize();
    final title = (data['title'] ?? 'SSD Manager').toString().trim();
    final body = (data['body'] ?? '').toString().trim();
    if (body.isEmpty) return;

    final isAnnouncement = data['route'] == 'announcements';
    final payload = jsonEncode(data);
    if (isAnnouncement) {
      final preferences = SharedPreferencesAsync();
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
          iOS: const DarwinNotificationDetails(
            threadIdentifier: _notificationThreadId,
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

  static Future<void> clearAnnouncements() async {
    await initialize();
    await SharedPreferencesAsync().remove(_storedAnnouncementLines);
    await _plugin.cancel(id: _announcementNotificationId);
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
