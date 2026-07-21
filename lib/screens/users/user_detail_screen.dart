import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile_statistics.dart';
import '../../models/user.dart';
import '../../providers/api_providers.dart';
import '../../providers/auth_provider.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_views.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final int userId;

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  late Future<(User, ProfileStatistics)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(User, ProfileStatistics)> _load() async {
    final repo = ref.read(userRepositoryProvider);
    final user = await repo.userDetails(widget.userId);
    final stats = await repo.userStatistics(widget.userId);
    return (user, stats);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Sani-Profil')),
      body: FutureBuilder<(User, ProfileStatistics)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) return ErrorView(message: snapshot.error.toString(), onRetry: _refresh);
          final (user, stats) = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('Benutzername: ${user.username}'),
                        Text('E-Mail: ${user.email}'),
                        Text('Rolle: ${user.role.label}'),
                        Text('Status: ${user.status}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _StatisticsCard(stats: stats),
                const SizedBox(height: 12),
                if (currentUser?.role.canManageUsers == true)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Verwaltung', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          if (currentUser?.role.canManageRoles == true)
                            OutlinedButton.icon(
                              onPressed: () => _changeRole(context, user),
                              icon: const Icon(Icons.admin_panel_settings_outlined),
                              label: const Text('Rolle verwalten'),
                            ),
                          if (user.status == 'active')
                            OutlinedButton.icon(
                              onPressed: () => _deactivate(context, user),
                              icon: const Icon(Icons.block_outlined),
                              label: const Text('Account deaktivieren'),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () => _reactivate(context, user),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Account reaktivieren'),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _markDeletion(context, user),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Zur Löschung vormerken'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deactivate(BuildContext context, User user) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Account deaktivieren?',
      message: '${user.fullName} kann sich danach nicht mehr anmelden. Aktive Sitzungen werden widerrufen.',
      confirmLabel: 'Deaktivieren',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(userRepositoryProvider).deactivate(user.id);
    await _refresh();
  }

  Future<void> _reactivate(BuildContext context, User user) async {
    await ref.read(userRepositoryProvider).reactivate(user.id);
    await _refresh();
  }

  Future<void> _markDeletion(BuildContext context, User user) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Löschung vormerken?',
      message: '${user.fullName} wird mit 30 Tagen Frist zur endgültigen Löschung vorgemerkt.',
      confirmLabel: 'Vormerken',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(userRepositoryProvider).markDeletion(user.id);
    await _refresh();
  }

  Future<void> _changeRole(BuildContext context, User user) async {
    var selected = user.role;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rolle verwalten'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => DropdownButtonFormField<UserRole>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Neue Rolle'),
            items: const [
              DropdownMenuItem(value: UserRole.sanitaeter, child: Text('Schulsanitäter')),
              DropdownMenuItem(value: UserRole.saniLeitung, child: Text('Sani-Leitung')),
              DropdownMenuItem(value: UserRole.teacher, child: Text('Lehreraufsicht')),
            ],
            onChanged: (value) => setDialogState(() => selected = value ?? user.role),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Speichern')),
        ],
      ),
    );
    if (confirmed != true || selected == user.role) return;
    await ref.read(userRepositoryProvider).changeRole(user.id, selected);
    await _refresh();
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({required this.stats});

  final ProfileStatistics stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dienststatistik', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text('Absolvierte Dienste: ${stats.completedCount}'),
            Text('Geplante Dienste: ${stats.upcomingCount}'),
            Text('Krankmeldungen: ${stats.sickCount}'),
            const SizedBox(height: 12),
            Text('Absolvierte Tage', style: Theme.of(context).textTheme.titleMedium),
            if (stats.completedDates.isEmpty)
              const Text('Keine absolvierten Dienste vorhanden.')
            else
              for (final date in stats.completedDates) Text(DateFormatters.dutyDate(date)),
          ],
        ),
      ),
    );
  }
}
