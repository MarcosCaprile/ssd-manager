import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/device_session.dart';
import '../../models/profile_statistics.dart';
import '../../providers/api_providers.dart';
import '../../providers/auth_provider.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_views.dart';
import '../auth/change_password_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<(ProfileStatistics, List<DeviceSession>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(ProfileStatistics, List<DeviceSession>)> _load() async {
    final repo = ref.read(userRepositoryProvider);
    final stats = await repo.myStatistics();
    final devices = await repo.devices();
    return (stats, devices);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Abmelden',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: user == null
          ? const LoadingView()
          : FutureBuilder<(ProfileStatistics, List<DeviceSession>)>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
                if (snapshot.hasError) return ErrorView(message: snapshot.error.toString(), onRetry: _refresh);
                final (stats, devices) = snapshot.data!;
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
                              Text('Schul-E-Mail: ${user.email}'),
                              Text('Rolle: ${user.role.label}'),
                              Text('Accountstatus: ${user.status}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ProfileStatisticsCard(stats: stats),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Sicherheit', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ChangePasswordScreen(forceChange: false),
                                  ),
                                ),
                                icon: const Icon(Icons.lock_reset_outlined),
                                label: const Text('Passwort ändern'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DevicesCard(devices: devices, onChanged: _refresh),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ProfileStatisticsCard extends StatelessWidget {
  const _ProfileStatisticsCard({required this.stats});

  final ProfileStatistics stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Eigene Dienststatistik', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text('Tatsächlich absolvierte Dienste: ${stats.completedCount}'),
            Text('Zukünftige geplante Dienste: ${stats.upcomingCount}'),
            Text('Krankmeldungen: ${stats.sickCount}'),
            const SizedBox(height: 12),
            Text('Zukünftige Dienste', style: Theme.of(context).textTheme.titleMedium),
            if (stats.upcomingDates.isEmpty)
              const Text('Keine geplanten Dienste vorhanden.')
            else
              for (final date in stats.upcomingDates) Text(DateFormatters.dutyDate(date)),
            const SizedBox(height: 12),
            Text('Absolvierte Dienste', style: Theme.of(context).textTheme.titleMedium),
            if (stats.completedDates.isEmpty)
              const Text('Du hast bisher noch keinen SSD-Dienst absolviert.')
            else
              for (final date in stats.completedDates) Text(DateFormatters.dutyDate(date)),
          ],
        ),
      ),
    );
  }
}

class _DevicesCard extends ConsumerWidget {
  const _DevicesCard({required this.devices, required this.onChanged});

  final List<DeviceSession> devices;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Angemeldete Geräte', style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Andere Geräte abmelden?',
                      message: 'Alle anderen aktiven Sitzungen werden widerrufen.',
                      confirmLabel: 'Abmelden',
                      destructive: true,
                    );
                    if (!confirmed) return;
                    await ref.read(userRepositoryProvider).revokeOtherDevices();
                    await onChanged();
                  },
                  child: const Text('Andere abmelden'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (devices.isEmpty)
              const Text('Keine aktiven Geräte gefunden.')
            else
              for (final device in devices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(device.platform == 'ios' ? Icons.phone_iphone : Icons.phone_android),
                  title: Text(device.deviceName),
                  subtitle: Text(
                    '${device.platform} · ${device.deviceModel}\n'
                    'Login: ${DateFormatters.timestamp(device.createdAt)} · '
                    'Zuletzt: ${DateFormatters.timestamp(device.lastActiveAt)}',
                  ),
                  isThreeLine: true,
                  trailing: device.isCurrent
                      ? const Chip(label: Text('Dieses Gerät'))
                      : IconButton(
                          tooltip: 'Gerät abmelden',
                          icon: const Icon(Icons.logout),
                          onPressed: () async {
                            final confirmed = await showConfirmDialog(
                              context,
                              title: 'Gerät abmelden?',
                              message: 'Diese Sitzung wird widerrufen.',
                              confirmLabel: 'Abmelden',
                              destructive: true,
                            );
                            if (!confirmed) return;
                            await ref.read(userRepositoryProvider).revokeDevice(device.id);
                            await onChanged();
                          },
                        ),
                ),
          ],
        ),
      ),
    );
  }
}
