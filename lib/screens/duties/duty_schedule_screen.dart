import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/duty_day.dart';
import '../../models/user.dart';
import '../../providers/api_providers.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_colors.dart';
import '../../utils/date_formatters.dart';
import '../../utils/duty_rules.dart';
import '../../utils/user_error_message.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_views.dart';
import 'duty_editor_sheets.dart';

class DutyScheduleScreen extends ConsumerStatefulWidget {
  const DutyScheduleScreen({super.key, this.active = true});

  final bool active;

  @override
  ConsumerState<DutyScheduleScreen> createState() => _DutyScheduleScreenState();
}

class _DutyScheduleScreenState extends ConsumerState<DutyScheduleScreen> {
  static const _liveRefreshInterval = Duration(seconds: 2);

  final _upcomingKey = GlobalKey<_DutyListState>();
  final _historyKey = GlobalKey<_DutyListState>();
  Timer? _liveRefreshTimer;
  bool _liveRefreshRunning = false;

  @override
  void initState() {
    super.initState();
    _liveRefreshTimer = Timer.periodic(
      _liveRefreshInterval,
      (_) => _liveRefresh(),
    );
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(dutyRevisionProvider, (previous, next) {
      if (previous != next) {
        _refreshAll(preserveOnError: true);
      }
    });
    final user = ref.watch(authControllerProvider).user;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dienstplan'),
          actions: [
            if (user?.role.canManageDuties == true)
              PopupMenuButton<_ManagerAction>(
                tooltip: 'Dienstplan verwalten',
                icon: const Icon(Icons.add_circle_outline),
                onSelected: _handleManagerAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ManagerAction.addDay,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.event_available_outlined),
                      title: Text('Diensttag hinzufügen'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ManagerAction.addClosure,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.event_busy_outlined,
                        color: AppColors.error,
                      ),
                      title: Text('Ausfall oder Ferien'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ManagerAction.resetClosure,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.event_repeat_outlined),
                      title: Text('Ausfall/Ferien aufheben'),
                    ),
                  ),
                ],
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Kommende 14 Tage'),
              Tab(text: 'Vergangenheit'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DutyList(key: _upcomingKey, mode: _DutyListMode.upcoming),
            _DutyList(key: _historyKey, mode: _DutyListMode.history),
          ],
        ),
      ),
    );
  }

  Future<void> _handleManagerAction(_ManagerAction action) async {
    final repository = ref.read(dutyRepositoryProvider);
    final bool changed;
    if (action == _ManagerAction.addDay) {
      changed = await showDutyDayEditor(
        context: context,
        repository: repository,
      );
    } else if (action == _ManagerAction.addClosure) {
      changed = await showClosureEditor(
        context: context,
        repository: repository,
      );
    } else {
      changed = await showClosureResetEditor(
        context: context,
        repository: repository,
      );
    }
    if (changed) {
      await _refreshAll(preserveOnError: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dienstplan wurde aktualisiert.')),
        );
      }
    }
  }

  Future<void> _refreshAll({bool preserveOnError = false}) async {
    await Future.wait([
      if (_upcomingKey.currentState != null)
        _upcomingKey.currentState!.refresh(preserveOnError: preserveOnError),
      if (_historyKey.currentState != null)
        _historyKey.currentState!.refresh(preserveOnError: preserveOnError),
    ]);
  }

  Future<void> _liveRefresh() async {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    if (!widget.active || !isForeground || _liveRefreshRunning) return;
    _liveRefreshRunning = true;
    try {
      await _refreshAll(preserveOnError: true);
    } finally {
      _liveRefreshRunning = false;
    }
  }
}

enum _ManagerAction { addDay, addClosure, resetClosure }

enum _DutyListMode { upcoming, history }

class _DutyList extends ConsumerStatefulWidget {
  const _DutyList({super.key, required this.mode});

  final _DutyListMode mode;

  @override
  ConsumerState<_DutyList> createState() => _DutyListState();
}

class _DutyListState extends ConsumerState<_DutyList>
    with AutomaticKeepAliveClientMixin {
  late Future<List<DutyDay>> _future;
  DateTime? _historyDate;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DutyDay>> _load() async {
    final repository = ref.read(dutyRepositoryProvider);
    final days = widget.mode == _DutyListMode.upcoming
        ? await repository.upcoming()
        : await repository.history(date: _historyDate);
    return days;
  }

  Future<void> refresh({bool preserveOnError = false}) async {
    if (preserveOnError) {
      try {
        final days = await _load();
        if (mounted) setState(() => _future = Future.value(days));
      } catch (_) {
        // Die Speicherung war erfolgreich. Ein fehlgeschlagenes Nachladen
        // darf nicht nachträglich als fehlgeschlagene Aktion erscheinen.
      }
      return;
    }
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const DelayedLoadingView();

    final list = _buildList(user);
    if (widget.mode == _DutyListMode.upcoming) return list;
    return Column(
      children: [
        _HistoryDateFilter(
          selectedDate: _historyDate,
          onSelect: _selectHistoryDate,
          onClear: _historyDate == null ? null : _clearHistoryDate,
        ),
        Expanded(child: list),
      ],
    );
  }

  Widget _buildList(User user) {
    return FutureBuilder<List<DutyDay>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const DelayedLoadingView(
            message: 'Dienstplan wird geladen ...',
          );
        }
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error, onRetry: refresh);
        }
        final days = snapshot.data ?? [];
        if (days.isEmpty) {
          return EmptyView(
            icon: Icons.event_busy_outlined,
            title: widget.mode == _DutyListMode.upcoming
                ? 'Keine kommenden Dienste'
                : _historyDate == null
                ? 'Keine vergangenen Dienste'
                : 'Kein Eintrag an diesem Datum',
            message: widget.mode == _DutyListMode.upcoming
                ? 'Für die kommenden 14 Tage wurden keine Diensttage gefunden.'
                : _historyDate == null
                ? 'Im letzten Jahr wurden keine Diensttage gespeichert.'
                : 'Wähle ein anderes Datum oder setze den Filter zurück.',
          );
        }
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemBuilder: (context, index) => _DutyDayCard(
              day: days[index],
              currentUser: user,
              readOnly: widget.mode == _DutyListMode.history,
              onChanged: () => refresh(preserveOnError: true),
            ),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemCount: days.length,
          ),
        );
      },
    );
  }

  Future<void> _selectHistoryDate() async {
    final today = DateTime.now();
    final lastDate = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 1));
    final selected = await showDatePicker(
      context: context,
      initialDate: _historyDate ?? lastDate,
      firstDate: lastDate.subtract(const Duration(days: 365)),
      lastDate: lastDate,
      helpText: 'DATUM IN DER VERGANGENHEIT',
      cancelText: 'ABBRECHEN',
      confirmText: 'SUCHEN',
    );
    if (selected == null) return;
    setState(() {
      _historyDate = selected;
      _future = _load();
    });
  }

  void _clearHistoryDate() {
    setState(() {
      _historyDate = null;
      _future = _load();
    });
  }
}

class _HistoryDateFilter extends StatelessWidget {
  const _HistoryDateFilter({
    required this.selectedDate,
    required this.onSelect,
    required this.onClear,
  });

  final DateTime? selectedDate;
  final VoidCallback onSelect;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: scheme.surface,
                  minimumSize: const Size(0, 42),
                ),
                onPressed: onSelect,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  selectedDate == null
                      ? 'Nach Datum suchen'
                      : DateFormatters.dutyDate(selectedDate!),
                ),
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Datumsfilter zurücksetzen',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
      ),
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
    final visibleAssignments = day.assignments
        .where(
          (assignment) =>
              assignment.status != 'cancelled' &&
              assignment.status != 'admin_removed',
        )
        .toList();
    final selfAssignment = day.assignmentForUser(currentUser.id);
    final canBook =
        !readOnly &&
        day.isActive &&
        !day.isClosed &&
        DutyRules.isWithinUpcomingWindow(now, day.date) &&
        currentUser.role.canAssignSelf &&
        !day.isFull &&
        selfAssignment == null;
    final canCancel =
        !readOnly &&
        selfAssignment != null &&
        DutyRules.canCancelRegularly(now, day.date);
    final canSickReport =
        !readOnly &&
        selfAssignment != null &&
        DutyRules.canReportSick(now, day.date);

    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: day.isClosed
          ? AppColors.error.withValues(alpha: 0.055)
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: day.isClosed
              ? AppColors.error.withValues(alpha: 0.5)
              : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              DateFormatters.dutyWeekday(day.date),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            DateFormatters.dutyDate(day.date),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      if (day.title != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          day.title!,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: day.isClosed
                                ? AppColors.error
                                : scheme.onSurface,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusChip(day: day),
                if (currentUser.role.canManageDuties && !readOnly)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Tag bearbeiten',
                    onPressed: () => _edit(context, ref),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
              ],
            ),
            if (day.description != null) ...[
              const SizedBox(height: 6),
              Text(
                day.description!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            if (day.isClosed)
              const Row(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 18,
                    color: AppColors.error,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Kein Schulsanitätsdienst',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else if (visibleAssignments.isEmpty)
              Text(
                'Noch niemand eingetragen',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              Column(
                children: [
                  for (final assignment in visibleAssignments)
                    _AssignmentRow(
                      assignment: assignment,
                      canRemove:
                          currentUser.role.canManageDuties &&
                          !readOnly &&
                          assignment.status == 'planned',
                      onRemove: () => _adminRemove(context, ref, assignment),
                    ),
                ],
              ),
            if (!readOnly && !day.isClosed) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (canBook)
                    _CompactAction(
                      icon: Icons.add,
                      label: 'Eintragen',
                      filled: true,
                      onPressed: () => _selfAssign(context, ref),
                    ),
                  if (canCancel)
                    _CompactAction(
                      icon: Icons.logout,
                      label: 'Austragen',
                      onPressed: () => _selfCancel(context, ref),
                    ),
                  if (canSickReport)
                    _CompactAction(
                      icon: Icons.sick_outlined,
                      label: 'Krankmelden',
                      color: AppColors.error,
                      filled: true,
                      onPressed: () => _sickReport(context, ref),
                    ),
                  if (currentUser.role.canManageDuties && day.isActive)
                    _CompactAction(
                      icon: Icons.person_add_alt_1_outlined,
                      label: 'Sani hinzufügen',
                      onPressed: day.isFull
                          ? null
                          : () => _adminAssign(context, ref),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final changed = await showDutyDayEditor(
      context: context,
      repository: ref.read(dutyRepositoryProvider),
      day: day,
    );
    if (changed) await onChanged();
  }

  Future<void> _selfAssign(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Dienst übernehmen?',
      message:
          'Möchtest du dich für den SSD-Dienst am ${DateFormatters.dutyDate(day.date)} eintragen?',
      confirmLabel: 'Eintragen',
    );
    if (!confirmed || !context.mounted) return;
    final succeeded = await _runAction(
      context,
      () => ref.read(dutyRepositoryProvider).selfAssign(day.date),
    );
    if (succeeded) await onChanged();
    if (succeeded && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Du wurdest eingetragen.')));
    }
  }

  Future<void> _selfCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Dienst austragen?',
      message:
          'Der Platz wird wieder freigegeben und andere Sanis können informiert werden.',
      confirmLabel: 'Austragen',
    );
    if (!confirmed || !context.mounted) return;
    final succeeded = await _runAction(
      context,
      () => ref.read(dutyRepositoryProvider).selfCancel(day.date),
    );
    if (succeeded) await onChanged();
  }

  Future<void> _sickReport(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Krankmeldung bestätigen?',
      message:
          'Es wird eine dringende Benachrichtigung an andere Sanis gesendet.',
      confirmLabel: 'Krankmelden',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final succeeded = await _runAction(
      context,
      () => ref.read(dutyRepositoryProvider).sickReport(day.date),
    );
    if (succeeded) await onChanged();
  }

  Future<void> _adminRemove(
    BuildContext context,
    WidgetRef ref,
    DutyAssignment assignment,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sani entfernen?',
      message:
          '${assignment.fullName} wird aus dem Dienst am ${DateFormatters.dutyDate(day.date)} entfernt.',
      confirmLabel: 'Entfernen',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final succeeded = await _runAction(
      context,
      () =>
          ref.read(dutyRepositoryProvider).adminRemove(day.date, assignment.id),
    );
    if (succeeded) await onChanged();
  }

  Future<void> _adminAssign(BuildContext context, WidgetRef ref) async {
    final succeeded = await _runAction(context, () async {
      final users = await ref.read(userRepositoryProvider).users();
      final assignedIds = day.assignments.map((item) => item.userId).toSet();
      final candidates = users
          .where(
            (user) =>
                user.isActive &&
                user.role.isSanitaryRole &&
                !assignedIds.contains(user.id),
          )
          .toList();
      if (!context.mounted) return;
      final selected = await showModalBottomSheet<User>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _SaniPicker(candidates: candidates),
      );
      if (selected == null || !context.mounted) return;
      final confirmed = await showConfirmDialog(
        context,
        title: 'Sani eintragen?',
        message:
            '${selected.fullName} wird für den Dienst am ${DateFormatters.dutyDate(day.date)} eingetragen.',
        confirmLabel: 'Eintragen',
      );
      if (!confirmed) return;
      await ref.read(dutyRepositoryProvider).adminAssign(day.date, selected.id);
    });
    if (succeeded) await onChanged();
  }

  Future<bool> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
      return false;
    }
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.assignment,
    required this.canRemove,
    required this.onRemove,
  });

  final DutyAssignment assignment;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            assignment.isSick ? Icons.healing_outlined : Icons.person_outline,
            size: 18,
            color: assignment.isSick ? AppColors.error : AppColors.primaryBlue,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              assignment.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _assignmentStatus(assignment),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (canRemove)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Aus Dienst entfernen',
              onPressed: onRemove,
              icon: const Icon(
                Icons.remove_circle_outline,
                size: 20,
                color: AppColors.error,
              ),
            ),
        ],
      ),
    );
  }

  String _assignmentStatus(DutyAssignment assignment) =>
      switch (assignment.status) {
        'completed' => 'Absolviert',
        'sick_reported' => 'Krank',
        'cancelled' => 'Ausgetragen',
        'admin_removed' => 'Entfernt',
        _ => assignment.assignmentType == 'self' ? 'Eingetragen' : 'Zugewiesen',
      };
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: filled && color != null
          ? WidgetStatePropertyAll(color)
          : null,
    );
    return filled
        ? FilledButton.icon(
            style: style,
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : OutlinedButton.icon(
            style: style,
            onPressed: onPressed,
            icon: Icon(icon, size: 18, color: color),
            label: Text(label, style: TextStyle(color: color)),
          );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.day});

  final DutyDay day;

  @override
  Widget build(BuildContext context) {
    final color = day.isClosed
        ? AppColors.error
        : day.isFull
        ? AppColors.success
        : day.occupiedSlots >= (day.capacity / 2).ceil()
        ? AppColors.warning
        : AppColors.primaryBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        day.isClosed ? 'Ausfall' : '${day.occupiedSlots}/${day.capacity}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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
        .where(
          (user) => user.fullName.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sani hinzufügen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
