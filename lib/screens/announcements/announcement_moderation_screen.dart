import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/announcement_report.dart';
import '../../models/user.dart';
import '../../providers/api_providers.dart';
import '../../providers/auth_provider.dart';
import '../../utils/date_formatters.dart';
import '../../utils/user_error_message.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_views.dart';

class AnnouncementModerationScreen extends ConsumerStatefulWidget {
  const AnnouncementModerationScreen({super.key});

  @override
  ConsumerState<AnnouncementModerationScreen> createState() =>
      _AnnouncementModerationScreenState();
}

class _AnnouncementModerationScreenState
    extends ConsumerState<AnnouncementModerationScreen> {
  late Future<List<AnnouncementReport>> _future;
  int? _workingReportId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AnnouncementReport>> _load() {
    return ref.read(announcementRepositoryProvider).reports();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inhaltsmeldungen'),
        actions: [
          IconButton(
            tooltip: 'Meldungen aktualisieren',
            onPressed: _workingReportId == null ? _refresh : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<AnnouncementReport>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const DelayedLoadingView(
              message: 'Inhaltsmeldungen werden geladen ...',
            );
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error, onRetry: _refresh);
          }
          final reports = snapshot.data ?? const [];
          final currentUser = ref.watch(authControllerProvider).user;
          if (reports.isEmpty) {
            return const EmptyView(
              icon: Icons.verified_user_outlined,
              title: 'Keine Inhaltsmeldungen',
              message: 'Gemeldete Ankündigungen erscheinen hier zur Prüfung.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final report = reports[index];
                return _ReportCard(
                  report: report,
                  working: _workingReportId == report.id,
                  onAction:
                      report.isOpen && currentUser?.id != report.senderUserId
                      ? (action) => _moderate(report, action)
                      : null,
                  isOwnContent: currentUser?.id == report.senderUserId,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _moderate(
    AnnouncementReport report,
    AnnouncementModerationAction action,
  ) async {
    final (title, message, confirmLabel, destructive) = switch (action) {
      AnnouncementModerationAction.dismiss => (
        'Meldung schließen?',
        'Der Inhalt bleibt sichtbar und die Meldung wird als unbedenklich geschlossen.',
        'Schließen',
        false,
      ),
      AnnouncementModerationAction.remove => (
        'Inhalt entfernen?',
        'Text und Anhänge werden für alle Personen entfernt. Im Chat bleibt ein Moderationshinweis sichtbar.',
        'Entfernen',
        true,
      ),
      AnnouncementModerationAction.removeAndDeactivate => (
        'Inhalt entfernen und Account sperren?',
        '${report.senderName} kann sich danach nicht mehr anmelden. Alle aktiven Sitzungen werden widerrufen.',
        'Entfernen und sperren',
        true,
      ),
    };
    final confirmed = await showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    );
    if (!confirmed || !mounted) return;
    setState(() => _workingReportId = report.id);
    try {
      await ref
          .read(announcementRepositoryProvider)
          .moderateReport(reportId: report.id, action: action);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == AnnouncementModerationAction.dismiss
                  ? 'Die Meldung wurde geschlossen.'
                  : 'Der gemeldete Inhalt wurde entfernt.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _workingReportId = null);
    }
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.working,
    required this.onAction,
    required this.isOwnContent,
  });

  final AnnouncementReport report;
  final bool working;
  final ValueChanged<AnnouncementModerationAction>? onAction;
  final bool isOwnContent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = report.isOpen ? scheme.error : scheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    report.reason.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    child: Text(
                      report.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Gemeldet von ${report.reporterName} · ${DateFormatters.timestamp(report.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 22),
            Text(
              report.senderName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              UserRole.fromJson(report.senderRole).label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                report.message.isEmpty ? 'Nur Anhänge' : report.message,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (report.attachmentCount > 0) ...[
              const SizedBox(height: 7),
              Text(
                '${report.attachmentCount} Anhang/Anhänge · ${report.availableAttachmentCount} verfügbar',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (report.details?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                'Zusätzliche Angaben',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 3),
              Text(report.details!),
            ],
            if (isOwnContent && report.isOpen) ...[
              const SizedBox(height: 12),
              Text(
                'Diese Meldung betrifft deinen eigenen Inhalt und muss von einer anderen verantwortlichen Person bearbeitet werden.',
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: working
                          ? null
                          : () =>
                                onAction!(AnnouncementModerationAction.dismiss),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Unbedenklich'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: working
                          ? null
                          : () => _showRemovalOptions(context),
                      icon: working
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.delete_outline),
                      label: const Text('Entfernen'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showRemovalOptions(BuildContext context) async {
    final action = await showModalBottomSheet<AnnouncementModerationAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Nur Inhalt entfernen'),
              subtitle: const Text('Text und Anhänge werden im Chat ersetzt.'),
              onTap: () => Navigator.of(
                context,
              ).pop(AnnouncementModerationAction.remove),
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('Entfernen und Account sperren'),
              subtitle: Text('${report.senderName} wird sofort abgemeldet.'),
              onTap: () => Navigator.of(
                context,
              ).pop(AnnouncementModerationAction.removeAndDeactivate),
            ),
          ],
        ),
      ),
    );
    if (action != null) onAction?.call(action);
  }
}
