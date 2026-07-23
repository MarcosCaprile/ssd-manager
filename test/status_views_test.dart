import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/widgets/status_views.dart';

void main() {
  testWidgets('delayed loading indicator stays hidden for short loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DelayedLoadingView(message: 'Test wird geladen ...'),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Test wird geladen ...'), findsOneWidget);
  });
}
