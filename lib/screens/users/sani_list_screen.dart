import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../../providers/api_providers.dart';
import '../../providers/auth_provider.dart';
import '../../utils/date_formatters.dart';
import '../../utils/user_error_message.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_views.dart';
import 'bulk_user_screen.dart';
import 'user_detail_screen.dart';

class SaniListScreen extends ConsumerStatefulWidget {
  const SaniListScreen({super.key, this.active = true});

  final bool active;

  @override
  ConsumerState<SaniListScreen> createState() => _SaniListScreenState();
}

class _SaniListScreenState extends ConsumerState<SaniListScreen> {
  static const _liveRefreshInterval = Duration(seconds: 2);

  late Future<List<User>> _future;
  List<User>? _cachedUsers;
  final _searchController = TextEditingController();
  String _query = '';
  Timer? _liveRefreshTimer;
  bool _liveRefreshRunning = false;

  @override
  void initState() {
    super.initState();
    _future = _loadInitial();
    _liveRefreshTimer = Timer.periodic(
      _liveRefreshInterval,
      (_) => _liveRefresh(),
    );
  }

  Future<List<User>> _fetch() => ref.read(userRepositoryProvider).users();

  Future<List<User>> _loadInitial() async {
    final users = List<User>.unmodifiable(await _fetch());
    _cachedUsers = users;
    return users;
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool preserveOnError = false}) async {
    if (_cachedUsers != null || preserveOnError) {
      try {
        final users = List<User>.unmodifiable(await _fetch());
        if (!mounted || listEquals(_cachedUsers, users)) return;
        _cachedUsers = users;
        setState(() => _future = SynchronousFuture(users));
      } catch (_) {
        if (!preserveOnError) rethrow;
        // Sichtbare Daten bleiben bei einem fehlgeschlagenen Live-Abgleich
        // erhalten. Der nächste Hintergrundlauf versucht es erneut.
      }
      return;
    }
    final next = _loadInitial();
    setState(() => _future = next);
    await next;
  }

  Future<void> _liveRefresh() async {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    if (!widget.active || !isForeground || _liveRefreshRunning) return;
    _liveRefreshRunning = true;
    try {
      await _refresh(preserveOnError: true);
    } finally {
      _liveRefreshRunning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(userRevisionProvider, (previous, next) {
      if (previous != next) {
        _refresh(preserveOnError: true);
      }
    });
    final currentUser = ref.watch(authControllerProvider).user;
    final canManage = currentUser?.role.canManageUsers == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Sani-Liste')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                final action = await showModalBottomSheet<_AddAccountAction>(
                  context: context,
                  showDragHandle: true,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_add_alt_1),
                          title: const Text('Einzelnen Account erstellen'),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(_AddAccountAction.single),
                        ),
                        ListTile(
                          leading: const Icon(Icons.table_view_outlined),
                          title: const Text('Bulk-Funktionen'),
                          subtitle: const Text(
                            'Excel-Import, Bearbeitung, Entfernen und Export',
                          ),
                          onTap: () =>
                              Navigator.of(context).pop(_AddAccountAction.bulk),
                        ),
                      ],
                    ),
                  ),
                );
                if (!context.mounted || action == null) return;
                final changed = action == _AddAccountAction.single
                    ? await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => const _CreateUserSheet(),
                      )
                    : await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const BulkUserScreen(),
                        ),
                      );
                if (changed == true) {
                  await _refresh(preserveOnError: true);
                }
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Account'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Nach Namen suchen',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Suche löschen',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (value) {
                setState(() => _query = value.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<User>>(
              future: _future,
              builder: (context, snapshot) {
                final users = _cachedUsers ?? snapshot.data;
                if (users == null &&
                    snapshot.connectionState != ConnectionState.done) {
                  return const DelayedLoadingView(
                    message: 'Sani-Liste wird geladen ...',
                  );
                }
                if (users == null && snapshot.hasError) {
                  return ErrorView(error: snapshot.error, onRetry: _refresh);
                }
                final visibleUsers = users ?? const <User>[];
                if (visibleUsers.isEmpty) {
                  return const EmptyView(
                    icon: Icons.groups_outlined,
                    title: 'Noch keine Personen',
                    message:
                        'Personen erscheinen hier, sobald Accounts erstellt wurden.',
                  );
                }
                final filtered = _query.isEmpty
                    ? visibleUsers
                    : visibleUsers
                          .where(
                            (user) =>
                                user.fullName.toLowerCase().contains(_query),
                          )
                          .toList();
                if (filtered.isEmpty) {
                  return const EmptyView(
                    icon: Icons.person_search_outlined,
                    title: 'Kein passender Name',
                    message: 'Versuche einen anderen Vor- oder Nachnamen.',
                  );
                }
                final active = filtered.where((user) => user.isActive).toList();
                final sanitary = active
                    .where((user) => user.role.isSanitaryRole)
                    .toList();
                final staff = active
                    .where((user) => !user.role.isSanitaryRole)
                    .toList();
                final inactive = canManage
                    ? filtered.where((user) => !user.isActive).toList()
                    : const <User>[];

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: [
                      if (sanitary.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Keine Schulsanitäter gefunden.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else ...[
                        Text(
                          'Schulsanitätsdienst',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        for (
                          var index = 0;
                          index < sanitary.length;
                          index++
                        ) ...[
                          _UserTile(
                            user: sanitary[index],
                            canManage: canManage,
                            onChanged: () => _refresh(preserveOnError: true),
                          ),
                          if (index != sanitary.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                      if (staff.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          'Lehreraufsicht und Sekretariat',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Diese Personen können den SSD einsehen, übernehmen aber keine Dienste.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        for (var index = 0; index < staff.length; index++) ...[
                          _UserTile(
                            user: staff[index],
                            canManage: canManage,
                            onChanged: () => _refresh(preserveOnError: true),
                          ),
                          if (index != staff.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                      if (inactive.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          'Deaktivierte Accounts',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nur Sani-Leitung und Lehreraufsicht können diese Accounts sehen und verwalten.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        for (
                          var index = 0;
                          index < inactive.length;
                          index++
                        ) ...[
                          _UserTile(
                            user: inactive[index],
                            canManage: canManage,
                            onChanged: () => _refresh(preserveOnError: true),
                          ),
                          if (index != inactive.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _AddAccountAction { single, bulk }

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.canManage,
    required this.onChanged,
  });

  final User user;
  final bool canManage;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final roleColor = switch (user.role) {
      UserRole.sanitaeter => const Color(0xFF2563EB),
      UserRole.saniLeitung => const Color(0xFF16A34A),
      _ => null,
    };
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: roleColor != null
              ? Border(left: BorderSide(color: roleColor, width: 5))
              : null,
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: roleColor != null
                ? roleColor.withValues(alpha: 0.16)
                : scheme.secondaryContainer,
            foregroundColor: roleColor ?? scheme.onSecondaryContainer,
            child: Text(
              user.firstName.isEmpty ? '?' : user.firstName.characters.first,
            ),
          ),
          title: Text(user.fullName),
          subtitle: Text(user.role.label),
          trailing: canManage ? const Icon(Icons.chevron_right) : null,
          onTap: canManage
              ? () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserDetailScreen(userId: user.id),
                    ),
                  );
                  await onChanged();
                }
              : null,
        ),
      ),
    );
  }
}

class _CreateUserSheet extends ConsumerStatefulWidget {
  const _CreateUserSheet();

  @override
  ConsumerState<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.sanitaeter;
  DateTime? _sanitaeterSince;
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickSanitaeterSince() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _sanitaeterSince ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
      helpText: 'Ab wann ist die Person Schulsanitäter?',
    );
    if (selected != null) setState(() => _sanitaeterSince = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role.isSanitaryRole && _sanitaeterSince == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wähle das Datum „Sanitäter seit“ aus.'),
        ),
      );
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Account erstellen?',
      message:
          '${_first.text.trim()} ${_last.text.trim()} wird als ${_role.label} angelegt. '
          'Das Datum „Sanitäter seit“ kann später nicht geändert werden.',
      confirmLabel: 'Erstellen',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .createUser(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            username: _username.text.trim(),
            email: _email.text.trim(),
            temporaryPassword: _password.text,
            role: _role.toJson(),
            sanitaeterSince: _sanitaeterSince,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).user;
    final canCreateAllRoles = currentUser?.role == UserRole.teacher;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Account erstellen',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _first,
                  decoration: const InputDecoration(labelText: 'Vorname'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _last,
                  decoration: const InputDecoration(labelText: 'Nachname'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Benutzername'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Schul-E-Mail'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Temporäres Startpasswort',
                  ),
                  validator: (value) => value == null || value.length < 10
                      ? 'Mindestens 10 Zeichen erforderlich.'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Rolle'),
                  items: [
                    const DropdownMenuItem(
                      value: UserRole.sanitaeter,
                      child: Text('Schulsanitäter'),
                    ),
                    if (canCreateAllRoles)
                      const DropdownMenuItem(
                        value: UserRole.saniLeitung,
                        child: Text('Sani-Leitung'),
                      ),
                    if (canCreateAllRoles)
                      const DropdownMenuItem(
                        value: UserRole.teacher,
                        child: Text('Lehreraufsicht'),
                      ),
                    if (canCreateAllRoles)
                      const DropdownMenuItem(
                        value: UserRole.sekretariat,
                        child: Text('Sekretariat'),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _role = value ?? UserRole.sanitaeter;
                      if (!_role.isSanitaryRole) _sanitaeterSince = null;
                    });
                  },
                ),
                if (_role.isSanitaryRole) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _pickSanitaeterSince,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      _sanitaeterSince == null
                          ? 'Sanitäter seit auswählen'
                          : 'Sanitäter seit ${DateFormatters.dutyDate(_sanitaeterSince!)}',
                    ),
                  ),
                  Text(
                    'Das Datum darf auch in der Zukunft liegen. Es wird beim Erstellen fest gespeichert und kann später nicht geändert werden.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving ? 'Account wird erstellt ...' : 'Account erstellen',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Pflichtfeld' : null;
}
