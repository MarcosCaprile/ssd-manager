import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/api_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/deep_link_provider.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/splash_screen.dart';
import 'themes/app_theme.dart';

class SsdManagerApp extends ConsumerWidget {
  const SsdManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'SSD Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
  StreamSubscription<dynamic>? _pushSubscription;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authControllerProvider.notifier).bootstrap();
      final push = ref.read(pushServiceProvider);
      final initial = await push.initialMessage();
      if (initial != null) {
        ref.read(deepLinkControllerProvider.notifier).setFromData(initial.data);
      }
      _pushSubscription = push.openedMessages.listen((message) {
        ref.read(deepLinkControllerProvider.notifier).setFromData(message.data);
      });
    });
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return switch (auth.status) {
      AuthStatus.checking => const SplashScreen(),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.authenticated => auth.user?.mustChangePassword == true
          ? const ChangePasswordScreen(forceChange: true)
          : const HomeShell(),
    };
  }
}
