import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushService {
  PushService();

  static bool _firebaseReady = false;

  static Future<void> initializeFirebaseIfConfigured() async {
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (_) {
      _firebaseReady = false;
    }
  }

  Future<String?> readToken() async {
    if (!_firebaseReady) return null;
    try {
      await FirebaseMessaging.instance.requestPermission();
      return FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Stream<RemoteMessage> get openedMessages {
    if (!_firebaseReady) return const Stream.empty();
    return FirebaseMessaging.onMessageOpenedApp;
  }

  Future<RemoteMessage?> initialMessage() async {
    if (!_firebaseReady) return null;
    try {
      return FirebaseMessaging.instance.getInitialMessage();
    } catch (_) {
      return null;
    }
  }
}
