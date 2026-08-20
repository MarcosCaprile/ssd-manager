import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/models/announcement.dart';
import 'package:ssd_manager/models/announcement_report.dart';
import 'package:ssd_manager/providers/api_providers.dart';
import 'package:ssd_manager/providers/auth_provider.dart';
import 'package:ssd_manager/models/user.dart';
import 'package:ssd_manager/repositories/announcement_repository.dart';
import 'package:ssd_manager/screens/announcements/announcement_moderation_screen.dart';

void main() {
  testWidgets('moderator can close an open report as harmless', (tester) async {
    final repository = _ModerationRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(() => _AuthenticatedController()),
        ],
        child: const MaterialApp(home: AnnouncementModerationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beleidigung oder Mobbing'), findsOneWidget);
    expect(find.text('Offen'), findsOneWidget);
    expect(find.text('Unbedenklich'), findsOneWidget);

    await tester.tap(find.text('Unbedenklich'));
    await tester.pumpAndSettle();
    expect(find.text('Meldung schließen?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Schließen'));
    await tester.pumpAndSettle();

    expect(repository.lastAction, AnnouncementModerationAction.dismiss);
  });
}

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => AuthState.authenticated(
    User(
      id: 99,
      firstName: 'Lea',
      lastName: 'Lehrerin',
      username: 'lea',
      email: 'lea@example.test',
      role: UserRole.teacher,
      status: 'active',
      mustChangePassword: false,
    ),
  );
}

class _ModerationRepository implements AnnouncementRepository {
  AnnouncementModerationAction? lastAction;

  final sampleReport = AnnouncementReport(
    id: 5,
    announcementId: 42,
    reason: AnnouncementReportReason.bullying,
    details: 'Bitte prüfen.',
    status: 'open',
    createdAt: DateTime.utc(2026, 8, 20, 8, 15),
    reporterName: 'Rita Rettich',
    senderUserId: 7,
    senderName: 'Thomas Tomate',
    senderRole: 'sanitaeter',
    senderStatus: 'active',
    message: 'Beispielnachricht',
    announcementCreatedAt: DateTime.utc(2026, 8, 20, 8),
    isModerated: false,
    attachmentCount: 1,
    availableAttachmentCount: 1,
  );

  @override
  Future<List<AnnouncementReport>> reports() async => [sampleReport];

  @override
  Future<void> moderateReport({
    required int reportId,
    required AnnouncementModerationAction action,
  }) async {
    lastAction = action;
  }

  @override
  Future<List<Announcement>> latest() async => const [];

  @override
  Future<void> report({
    required int announcementId,
    required AnnouncementReportReason reason,
    String? details,
  }) async {}

  @override
  Future<Announcement> send({
    required String message,
    List<int> attachmentIds = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AnnouncementAttachment> uploadAttachment({
    required String fileName,
    required Uint8List bytes,
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
