import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/attachment_storage.dart';
import '../../models/device_session.dart';
import '../../models/profile_statistics.dart';
import '../../models/user.dart';
import '../../providers/api_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/date_formatters.dart';
import '../../utils/user_error_message.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_views.dart';
import '../auth/change_password_screen.dart';
import 'attachment_storage_screen.dart';

typedef _ProfileData = ({
  ProfileStatistics? statistics,
  List<DeviceSession> devices,
  AttachmentStorageSummary storage,
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<_ProfileData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProfileData> _load() async {
    final repo = ref.read(userRepositoryProvider);
    final user = ref.read(authControllerProvider).user;
    final results = await Future.wait<dynamic>([
      if (user?.role.hasDutyStatistics == true) repo.myStatistics(),
      repo.devices(),
      repo.attachmentStorage(),
    ]);
    var index = 0;
    final statistics = user?.role.hasDutyStatistics == true
        ? results[index++] as ProfileStatistics
        : null;
    return (
      statistics: statistics,
      devices: results[index++] as List<DeviceSession>,
      storage: results[index] as AttachmentStorageSummary,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Wirklich abmelden?',
      message:
          'Du musst dich anschließend erneut mit deinen Zugangsdaten anmelden.',
      confirmLabel: 'Abmelden',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
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
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: user == null
          ? const LoadingView()
          : FutureBuilder<_ProfileData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingView(message: 'Profil wird geladen ...');
                }
                if (snapshot.hasError) {
                  return ErrorView(error: snapshot.error, onRetry: _refresh);
                }
                final data = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _IdentityCard(user: user),
                      if (data.statistics != null) ...[
                        const SizedBox(height: 12),
                        _ProfileStatisticsCard(stats: data.statistics!),
                      ],
                      const SizedBox(height: 12),
                      _StorageCard(storage: data.storage, onChanged: _refresh),
                      const SizedBox(height: 12),
                      const _AppearanceCard(),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Sicherheit',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ChangePasswordScreen(
                                      forceChange: false,
                                    ),
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
                      _DevicesCard(devices: data.devices, onChanged: _refresh),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Card(
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
            if (user.role.isSanitaryRole)
              Text(
                'Sanitäter seit: ${user.sanitaeterSince == null ? 'Nicht hinterlegt' : DateFormatters.dutyDate(user.sanitaeterSince!)}',
              ),
            Text('Accountstatus: ${user.status}'),
          ],
        ),
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.storage, required this.onChanged});

  final AttachmentStorageSummary storage;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AttachmentStorageScreen()),
          );
          await onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cloud-Speicher',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: storage.usedFraction),
              const SizedBox(height: 8),
              Text(
                '${_formatBytes(storage.usedBytes)} von ${_formatBytes(storage.limitBytes)} belegt',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              const Text('Dateien ansehen und Speicher freigeben'),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Darstellung', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.settings_suggest_outlined),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Hell'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dunkel'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) {
                ref
                    .read(themeControllerProvider.notifier)
                    .setMode(selection.first);
              },
            ),
          ],
        ),
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
            Text(
              'Eigene Dienststatistik',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text('Tatsächlich absolvierte Dienste: ${stats.completedCount}'),
            Text('Zukünftige geplante Dienste: ${stats.upcomingCount}'),
            Text('Krankmeldungen: ${stats.sickCount}'),
            const SizedBox(height: 12),
            Text(
              'Zukünftige Dienste',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (stats.upcomingDates.isEmpty)
              const Text('Keine geplanten Dienste vorhanden.')
            else
              for (final date in stats.upcomingDates)
                Text(DateFormatters.dutyDate(date)),
            const SizedBox(height: 12),
            Text(
              'Absolvierte Dienste',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (stats.completedDates.isEmpty)
              const Text('Du hast bisher noch keinen SSD-Dienst absolviert.')
            else
              for (final date in stats.completedDates)
                Text(DateFormatters.dutyDate(date)),
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
    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Angemeldete Geräte',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed:
                      devices.where((device) => !device.isCurrent).isEmpty
                      ? null
                      : () async {
                          final confirmed = await showConfirmDialog(
                            context,
                            title: 'Andere Geräte abmelden?',
                            message:
                                'Alle anderen aktiven Sitzungen werden widerrufen.',
                            confirmLabel: 'Abmelden',
                            destructive: true,
                          );
                          if (!confirmed) return;
                          await run(() async {
                            await ref
                                .read(userRepositoryProvider)
                                .revokeOtherDevices();
                            await onChanged();
                          });
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
                  leading: Icon(
                    device.platform == 'ios'
                        ? Icons.phone_iphone
                        : Icons.phone_android,
                  ),
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
                            await run(() async {
                              await ref
                                  .read(userRepositoryProvider)
                                  .revokeDevice(device.id);
                              await onChanged();
                            });
                          },
                        ),
                ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(bytes >= 10 * 1024 * 1024 ? 0 : 1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
