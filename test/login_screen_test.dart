import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/screens/auth/login_screen.dart';
import 'package:ssd_manager/themes/app_theme.dart';

void main() {
  testWidgets('login screen renders required fields', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );

    expect(find.text('Willkommen bei SSD Manager'), findsOneWidget);
    expect(find.text('E-Mail oder Benutzername'), findsOneWidget);
    expect(find.text('Passwort'), findsOneWidget);
    expect(find.text('Anmelden'), findsOneWidget);
  });
}
