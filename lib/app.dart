import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/api_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/deep_link_provider.dart';
import 'providers/incoming_share_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/splash_screen.dart';
import 'themes/app_theme.dart';

class SsdManagerApp extends ConsumerWidget {
  const SsdManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    return MaterialApp(
      title: 'SSD Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('de', 'DE')],
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  StreamSubscription<Map<String, dynamic>>? _pushOpenSubscription;
  StreamSubscription<Map<String, dynamic>>? _pushReceiveSubscription;
  StreamSubscription<String>? _pushTokenSubscription;
  StreamSubscription<IncomingSharePayload>? _incomingShareSubscription;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final incomingShares = ref.read(incomingShareServiceProvider);
      _incomingShareSubscription = incomingShares.shares.listen(
        _handleIncomingShare,
      );
      await incomingShares.initialize();
      await ref.read(authControllerProvider.notifier).bootstrap();
      final push = ref.read(pushServiceProvider);
      final initial = await push.initialData();
      if (initial != null) {
        ref.read(deepLinkControllerProvider.notifier).setFromData(initial);
      }
      _pushOpenSubscription = push.openedData.listen((data) {
        ref.read(deepLinkControllerProvider.notifier).setFromData(data);
        _refreshForPush(data);
      });
      _pushReceiveSubscription = push.receivedData.listen(_refreshForPush);
      _pushTokenSubscription = push.tokenChanges.listen((_) async {
        if (ref.read(authControllerProvider).status !=
            AuthStatus.authenticated) {
          return;
        }
        try {
          await ref.read(authRepositoryProvider).updatePushToken();
        } catch (_) {
          // The next login/bootstrap retries token registration.
        }
      });
    });
  }

  void _handleIncomingShare(IncomingSharePayload payload) {
    ref.read(incomingShareProvider.notifier).set(payload);
    ref.read(deepLinkControllerProvider.notifier).setFromData(const {
      'route': 'announcements',
    });
  }

  void _refreshForPush(Map<String, dynamic> data) {
    switch (data['route']) {
      case 'announcements':
        ref.read(announcementRevisionProvider.notifier).bump();
        unawaited(_syncAnnouncementUnreadCount());
      case 'duty':
        ref.read(dutyRevisionProvider.notifier).bump();
      case 'users':
        ref.read(userRevisionProvider.notifier).bump();
    }
  }

  Future<void> _syncAnnouncementUnreadCount() async {
    final count = await ref.read(pushServiceProvider).announcementUnreadCount();
    if (!mounted) return;
    ref.read(announcementUnreadProvider.notifier).setCount(count);
  }

  @override
  void dispose() {
    _pushOpenSubscription?.cancel();
    _pushReceiveSubscription?.cancel();
    _pushTokenSubscription?.cancel();
    _incomingShareSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return switch (auth.status) {
      AuthStatus.checking => const SplashScreen(),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.authenticated =>
        auth.user?.mustChangePassword == true
            ? const ChangePasswordScreen(forceChange: true)
            : const HomeShell(),
    };
  }
}
