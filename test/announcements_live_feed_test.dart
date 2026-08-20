import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/models/announcement.dart';
import 'package:ssd_manager/models/announcement_report.dart';
import 'package:ssd_manager/models/user.dart';
import 'package:ssd_manager/providers/api_providers.dart';
import 'package:ssd_manager/providers/auth_provider.dart';
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

  testWidgets('long press on another users message opens reporting flow', (
    tester,
  ) async {
    final announcement = _announcement(3, 'Bitte diese Nachricht prüfen');
    final repository = _FakeAnnouncementRepository([announcement]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(
            () => _AuthenticatedController(_user(99)),
          ),
        ],
        child: const MaterialApp(home: AnnouncementsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Bitte diese Nachricht prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('Nachricht melden'), findsOneWidget);

    await tester.tap(find.text('Nachricht melden'));
    await tester.pumpAndSettle();
    expect(find.text('Meldegrund'), findsOneWidget);
    await tester.tap(
      find.byType(DropdownButtonFormField<AnnouncementReportReason>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spam oder sachfremder Inhalt').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Melden'));
    await tester.pumpAndSettle();

    expect(repository.reportedAnnouncementId, announcement.id);
  });

  testWidgets('long press lets the sender delete an own message', (
    tester,
  ) async {
    final announcement = _announcement(4, 'Eigene Testnachricht');
    final repository = _FakeAnnouncementRepository([announcement]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(
            () => _AuthenticatedController(_user(announcement.senderUserId)),
          ),
        ],
        child: const MaterialApp(home: AnnouncementsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Eigene Testnachricht'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nachricht löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Nachricht löschen'));
    await tester.pumpAndSettle();

    expect(repository.deletedAnnouncementId, announcement.id);
    expect(find.text('Diese Nachricht wurde gelöscht.'), findsOneWidget);
  });

  testWidgets('chat composer offers an explicit keyboard close action', (
    tester,
  ) async {
    final repository = _FakeAnnouncementRepository([
      _announcement(5, 'Nachricht für den Tastaturtest'),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(
            () => _AuthenticatedController(_user(99)),
          ),
        ],
        child: const MaterialApp(home: AnnouncementsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final composer = find.widgetWithText(TextField, 'Nachricht');
    expect(
      tester.widget<ListView>(find.byType(ListView)).keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
    expect(find.byTooltip('Tastatur schließen'), findsNothing);

    await tester.tap(composer);
    await tester.pump();
    final composerWidget = tester.widget<TextField>(composer);
    expect(find.byTooltip('Tastatur schließen'), findsOneWidget);
    expect(composerWidget.focusNode?.hasFocus, isTrue);

    await tester.tap(find.byTooltip('Tastatur schließen'));
    await tester.pump();
    expect(composerWidget.focusNode?.hasFocus, isFalse);
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

User _user(int id) => User(
  id: id,
  firstName: 'Demo',
  lastName: 'Person',
  username: 'demo.person$id',
  email: 'demo.person$id@example.test',
  role: UserRole.sanitaeter,
  status: 'active',
  mustChangePassword: false,
);

class _AuthenticatedController extends AuthController {
  _AuthenticatedController(this.user);

  final User user;

  @override
  AuthState build() => AuthState.authenticated(user);
}

class _FakeAnnouncementRepository implements AnnouncementRepository {
  _FakeAnnouncementRepository(this.announcements);

  final List<Announcement> announcements;
  int? reportedAnnouncementId;
  int? deletedAnnouncementId;

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
  Future<void> report({
    required int announcementId,
    required AnnouncementReportReason reason,
    String? details,
  }) async {
    reportedAnnouncementId = announcementId;
  }

  @override
  Future<void> deleteOwn(int announcementId) async {
    deletedAnnouncementId = announcementId;
  }

  @override
  Future<List<AnnouncementReport>> reports() async => const [];

  @override
  Future<void> moderateReport({
    required int reportId,
    required AnnouncementModerationAction action,
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
