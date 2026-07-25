import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/models/user.dart';
import 'package:ssd_manager/providers/api_providers.dart';
import 'package:ssd_manager/repositories/user_repository.dart';
import 'package:ssd_manager/screens/users/sani_list_screen.dart';
import 'package:ssd_manager/widgets/status_views.dart';

void main() {
  testWidgets(
    'live user refresh keeps content visible while request is pending',
    (tester) async {
      const initial = User(
        id: 1,
        firstName: 'Thomas',
        lastName: 'Tomate',
        username: 'Thomas T.',
        email: 'thomas@example.test',
        role: UserRole.sanitaeter,
        status: 'active',
        mustChangePassword: false,
      );
      final refresh = Completer<List<User>>();
      final repository = _QueuedUserRepository([
        Future.value(const [initial]),
        refresh.future,
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [userRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: SaniListScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Thomas Tomate'), findsOneWidget);
      expect(find.byType(DelayedLoadingView), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SaniListScreen)),
      );
      container.read(userRevisionProvider.notifier).bump();
      await tester.pump();

      expect(repository.calls, 2);
      expect(find.text('Thomas Tomate'), findsOneWidget);
      expect(find.byType(DelayedLoadingView), findsNothing);

      refresh.complete(const [initial]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _QueuedUserRepository implements UserRepository {
  _QueuedUserRepository(Iterable<Future<List<User>>> responses)
    : _responses = Queue.of(responses);

  final Queue<Future<List<User>>> _responses;
  int calls = 0;

  @override
  Future<List<User>> users() {
    calls++;
    return _responses.removeFirst();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
