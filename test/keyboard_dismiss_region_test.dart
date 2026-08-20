import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/widgets/keyboard_dismiss_region.dart';

void main() {
  testWidgets('tap outside the focused field removes text-input focus', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => KeyboardDismissRegion(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              TextField(key: const Key('input'), focusNode: focusNode),
              Expanded(
                child: GestureDetector(
                  key: const Key('outside'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('input')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('outside')));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('tap inside the focused field keeps text-input focus', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => KeyboardDismissRegion(child: child!),
        home: Scaffold(
          body: TextField(key: const Key('input'), focusNode: focusNode),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('input')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('input')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
  });
}
