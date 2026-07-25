import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/models/announcement.dart';
import 'package:ssd_manager/providers/api_providers.dart';
import 'package:ssd_manager/repositories/announcement_repository.dart';
import 'package:ssd_manager/screens/announcements/announcements_screen.dart';
import 'package:ssd_manager/widgets/status_views.dart';

void main() {
  testWidgets('open announcements render shared live-feed updates', (
    tester,
  ) async {
    final first = _announcement(1, 'Erste Live-Nachricht');
    final second = _announcement(2, 'Zweite Live-Nachricht');
    final repository = _FakeAnnouncementRepository([first]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: AnnouncementsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Erste Live-Nachricht'), findsOneWidget);
    expect(find.text('Zweite Live-Nachricht'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AnnouncementsScreen)),
    );
    container.read(announcementFeedProvider.notifier).replace([first, second]);
    await tester.pumpAndSettle();

    expect(find.text('Erste Live-Nachricht'), findsOneWidget);
    expect(find.text('Zweite Live-Nachricht'), findsOneWidget);
    expect(find.byType(DelayedLoadingView), findsNothing);
  });

  test('equivalent live feeds do not emit redundant state updates', () {
    final container = ProviderContainer();
    var notifications = 0;
    final subscription = container.listen<List<Announcement>?>(
      announcementFeedProvider,
      (_, _) => notifications++,
    );

    container.read(announcementFeedProvider.notifier).replace([
      _announcement(1, 'Unverändert'),
    ]);
    container.read(announcementFeedProvider.notifier).replace([
      _announcement(1, 'Unverändert'),
    ]);

    expect(notifications, 1);
    subscription.close();
    container.dispose();
  });
}

Announcement _announcement(int id, String message) {
  return Announcement(
    id: id,
    senderUserId: 9,
    senderName: 'Test Person',
    senderRole: 'sanitaeter',
    message: message,
    messageType: 'user',
    createdAt: DateTime.utc(2026, 7, 24, 12, id),
    attachments: const [],
  );
}

class _FakeAnnouncementRepository implements AnnouncementRepository {
  _FakeAnnouncementRepository(this.announcements);

  final List<Announcement> announcements;

  @override
  Future<List<Announcement>> latest() async => announcements;

  @override
  Future<AnnouncementAttachment> uploadAttachment({
    required String fileName,
    required Uint8List bytes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Announcement> send({
    required String message,
    List<int> attachmentIds = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> attachmentBytes(int attachmentId) {
    throw UnimplementedError();
  }

  @override
  void evictAttachment(int attachmentId) {}
}
