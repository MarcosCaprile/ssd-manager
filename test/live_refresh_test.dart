import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/models/profile_statistics.dart';
import 'package:ssd_manager/models/user.dart';
import 'package:ssd_manager/providers/api_providers.dart';
import 'package:ssd_manager/repositories/user_repository.dart';
import 'package:ssd_manager/screens/profile/profile_statistics_screen.dart';
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
      await tester.pump();

      expect(find.text('Thomas Tomate'), findsOneWidget);
      expect(find.byType(DelayedLoadingView), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'live statistics refresh keeps completed data visible while pending',
    (tester) async {
      final refresh = Completer<ProfileStatistics>();
      final repository = _QueuedUserRepository(
        const [],
        statisticsResponses: [Future.value(_statistics(1)), refresh.future],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [userRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: ProfileStatisticsScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Tatsächlich absolvierte Dienste: 1'), findsOneWidget);
      expect(find.byType(DelayedLoadingView), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileStatisticsScreen)),
      );
      container.read(dutyRevisionProvider.notifier).bump();
      await tester.pump();

      expect(find.text('Tatsächlich absolvierte Dienste: 1'), findsOneWidget);
      expect(find.byType(DelayedLoadingView), findsNothing);

      refresh.complete(_statistics(2));
      await tester.pumpAndSettle();

      expect(find.text('Tatsächlich absolvierte Dienste: 2'), findsOneWidget);
      expect(find.byType(DelayedLoadingView), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

ProfileStatistics _statistics(int completedCount) {
  return ProfileStatistics(
    completedCount: completedCount,
    upcomingCount: 0,
    sickCount: 0,
    completedDates: [DateTime(2026, 7, completedCount)],
    upcomingDates: const [],
  );
}

class _QueuedUserRepository implements UserRepository {
  _QueuedUserRepository(
    Iterable<Future<List<User>>> responses, {
    Iterable<Future<ProfileStatistics>> statisticsResponses = const [],
  }) : _responses = Queue.of(responses),
       _statisticsResponses = Queue.of(statisticsResponses);

  final Queue<Future<List<User>>> _responses;
  final Queue<Future<ProfileStatistics>> _statisticsResponses;
  int calls = 0;

  @override
  Future<List<User>> users() {
    calls++;
    return _responses.removeFirst();
  }

  @override
  Future<ProfileStatistics> myStatistics() {
    calls++;
    return _statisticsResponses.removeFirst();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
