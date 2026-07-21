import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/duty_day.dart';
import '../../models/user.dart';
import '../../providers/api_providers.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_colors.dart';
import '../../utils/date_formatters.dart';
import '../../utils/duty_rules.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_views.dart';

class DutyScheduleScreen extends StatelessWidget {
  const DutyScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dienstplan'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Kommende 14 Tage'),
              Tab(text: 'Vergangenheit'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DutyList(mode: _DutyListMode.upcoming),
            _DutyList(mode: _DutyListMode.history),
          ],
        ),
      ),
    );
  }
}

enum _DutyListMode { upcoming, history }

class _DutyList extends ConsumerStatefulWidget {
  const _DutyList({required this.mode});

  final _DutyListMode mode;

  @override
  ConsumerState<_DutyList> createState() => _DutyListState();
}

class _DutyListState extends ConsumerState<_DutyList> {
  late Future<List<DutyDay>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DutyDay>> _load() {
    final repo = ref.read(dutyRepositoryProvider);
    return widget.mode == _DutyListMode.upcoming ? repo.upcoming() : repo.history();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const LoadingView();

    return FutureBuilder<List<DutyDay>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(message: 'Dienstplan wird geladen ...');
        }
        if (snapshot.hasError) {
          return ErrorView(message: snapshot.error.toString(), onRetry: _refresh);
        }
        final days = snapshot.data ?? [];
        if (days.isEmpty) {
          return EmptyView(
            icon: Icons.event_busy_outlined,
            title: widget.mode == _DutyListMode.upcoming
                ? 'Keine kommenden Dienste'
                : 'Keine vergangenen Dienste',
            message: widget.mode == _DutyListMode.upcoming
                ? 'Für die kommenden 14 Tage wurden keine Diensttage gefunden.'
                : 'Du hast bisher noch keinen SSD-Dienst absolviert.',
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) => _DutyDayCard(
              day: days[index],
              currentUser: user,
              readOnly: widget.mode == _DutyListMode.history,
              onChanged: _refresh,
            ),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemCount: days.length,
          ),
        );
      },
    );
  }
}

class _DutyDayCard extends ConsumerWidget {
  const _DutyDayCard({
    required this.day,
    required this.currentUser,
    required this.readOnly,
    required this.onChanged,
  });

  final DutyDay day;
  final User currentUser;
  final bool readOnly;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isWeekend = DutyRules.isWeekend(day.date);
    final selfAssignment = day.assignmentForUser(currentUser.id);
    final canBook = !readOnly &&
        day.isActive &&
        !isWeekend &&
        DutyRules.canBook(now, day.date) &&
        currentUser.role.canAssignSelf &&
        !day.isFull &&
        selfAssignment == null;
    final canCancel = selfAssignment != null && DutyRules.canCancelRegularly(now, day.date);
    final canSickReport = selfAssignment != null && DutyRules.canReportSick(now, day.date);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormatters.dutyWeekday(day.date),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormatters.dutyDate(day.date),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _StatusChip(day: day, isWeekend: isWeekend),
              ],
            ),
            const SizedBox(height: 14),
            if (isWeekend)
              const Text('Kein Schulsanitätsdienst', style: TextStyle(color: AppColors.secondaryText))
            else if (day.assignments.isEmpty)
              const Text('Für diesen Tag hat sich noch niemand eingetragen')
            else
              Column(
                children: [
                  for (final assignment in day.assignments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        assignment.isSick ? Icons.healing_outlined : Icons.person_outline,
                        color: assignment.isSick ? AppColors.error : AppColors.primaryBlue,
                      ),
                      title: Text(assignment.fullName),
                      subtitle: Text(_assignmentStatus(assignment)),
                      trailing: currentUser.role.canManageDuties && !readOnly && assignment.status == 'planned'
                          ? IconButton(
                              tooltip: 'Aus Dienst entfernen',
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                              onPressed: () => _adminRemove(context, ref, assignment),
                            )
                          : null,
                    ),
                ],
              ),
            if (!readOnly) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canBook)
                    FilledButton.icon(
                      onPressed: () => _selfAssign(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Eintragen'),
                    ),
                  if (canCancel)
                    OutlinedButton.icon(
                      onPressed: () => _selfCancel(context, ref),
                      icon: const Icon(Icons.logout),
                      label: const Text('Austragen'),
                    ),
                  if (canSickReport)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                      onPressed: () => _sickReport(context, ref),
                      icon: const Icon(Icons.sick_outlined),
                      label: const Text('Krankmelden'),
                    ),
                  if (currentUser.role.canManageDuties && day.isActive && !isWeekend)
                    OutlinedButton.icon(
                      onPressed: day.isFull ? null : () => _adminAssign(context, ref),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Sani hinzufügen'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _assignmentStatus(DutyAssignment assignment) => switch (assignment.status) {
        'completed' => 'Absolviert',
        'sick_reported' => 'Krankgemeldet',
        'cancelled' => 'Ausgetragen',
        'admin_removed' => 'Administrativ entfernt',
        _ => assignment.assignmentType == 'self' ? 'Selbst eingetragen' : 'Administrativ eingetragen',
      };

  Future<void> _selfAssign(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Dienst übernehmen?',
      message: 'Möchtest du dich für den SSD-Dienst am ${DateFormatters.dutyDate(day.date)} eintragen?',
      confirmLabel: 'Eintragen',
    );
    if (!confirmed) return;
    await ref.read(dutyRepositoryProvider).selfAssign(day.date);
    await onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Du wurdest eingetragen.')));
    }
  }

  Future<void> _selfCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Dienst austragen?',
      message: 'Der Platz wird wieder freigegeben und andere Sanis können informiert werden.',
      confirmLabel: 'Austragen',
    );
    if (!confirmed) return;
    await ref.read(dutyRepositoryProvider).selfCancel(day.date);
    await onChanged();
  }

  Future<void> _sickReport(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Krankmeldung bestätigen?',
      message: 'Es wird eine dringende Benachrichtigung an andere Sanis gesendet.',
      confirmLabel: 'Krankmelden',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(dutyRepositoryProvider).sickReport(day.date);
    await onChanged();
  }

  Future<void> _adminRemove(
    BuildContext context,
    WidgetRef ref,
    DutyAssignment assignment,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sani entfernen?',
      message: '${assignment.fullName} wird aus dem Dienst am ${DateFormatters.dutyDate(day.date)} entfernt.',
      confirmLabel: 'Entfernen',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(dutyRepositoryProvider).adminRemove(day.date, assignment.id);
    await onChanged();
  }

  Future<void> _adminAssign(BuildContext context, WidgetRef ref) async {
    final users = await ref.read(userRepositoryProvider).users();
    final assignedIds = day.assignments.map((item) => item.userId).toSet();
    final candidates = users
        .where((user) => user.isActive && user.role != UserRole.teacher && !assignedIds.contains(user.id))
        .toList();
    if (!context.mounted) return;
    final selected = await showModalBottomSheet<User>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SaniPicker(candidates: candidates),
    );
    if (selected == null) return;
    await ref.read(dutyRepositoryProvider).adminAssign(day.date, selected.id);
    await onChanged();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.day, required this.isWeekend});

  final DutyDay day;
  final bool isWeekend;

  @override
  Widget build(BuildContext context) {
    final color = isWeekend
        ? AppColors.secondaryText
        : day.isFull
            ? AppColors.success
            : day.occupiedSlots >= 2
                ? AppColors.warning
                : AppColors.primaryBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isWeekend ? 'inaktiv' : '${day.occupiedSlots} von ${day.capacity}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SaniPicker extends StatefulWidget {
  const _SaniPicker({required this.candidates});

  final List<User> candidates;

  @override
  State<_SaniPicker> createState() => _SaniPickerState();
}

class _SaniPickerState extends State<_SaniPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.candidates
        .where((user) => user.fullName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sani hinzufügen', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Sani suchen',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Keine auswählbaren Sanis gefunden.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final user = filtered[index];
                        return ListTile(
                          leading: const Icon(Icons.person_add_alt_1_outlined),
                          title: Text(user.fullName),
                          subtitle: Text(user.role.label),
                          onTap: () => Navigator.of(context).pop(user),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
