import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_views.dart';
import '../auth/change_password_screen.dart';
import 'appearance_screen.dart';
import 'attachment_storage_screen.dart';
import 'contact_screen.dart';
import 'device_sessions_screen.dart';
import 'profile_statistics_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(body: DelayedLoadingView());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _IdentityCard(user: user),
          const SizedBox(height: 20),
          Text('Einstellungen', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (user.role.hasDutyStatistics)
                  _SettingsTile(
                    icon: Icons.bar_chart_outlined,
                    title: 'Dienststatistik',
                    subtitle: 'Geplante und absolvierte Dienste',
                    onTap: () =>
                        _open(context, const ProfileStatisticsScreen()),
                  ),
                _SettingsTile(
                  icon: Icons.cloud_outlined,
                  title: 'Cloud-Speicher',
                  subtitle: 'Dateien ansehen und Speicher freigeben',
                  onTap: () => _open(context, const AttachmentStorageScreen()),
                ),
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Darstellung',
                  subtitle: 'System, Hell oder Dunkel',
                  onTap: () => _open(context, const AppearanceScreen()),
                ),
                _SettingsTile(
                  icon: Icons.lock_reset_outlined,
                  title: 'Passwort ändern',
                  subtitle: 'Zugangsdaten und Sitzungen schützen',
                  onTap: () => _open(
                    context,
                    const ChangePasswordScreen(forceChange: false),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.devices_outlined,
                  title: 'Angemeldete Geräte',
                  subtitle: 'Aktive Sitzungen ansehen und abmelden',
                  onTap: () => _open(context, const DeviceSessionsScreen()),
                ),
                _SettingsTile(
                  icon: Icons.support_agent_outlined,
                  title: 'Kontakt und Support',
                  subtitle: 'Allgemeine Fragen und technische Unterstützung',
                  onTap: () => _open(context, const ContactScreen()),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Abmelden'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, Widget page) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Wirklich abmelden?',
      message:
          'Du musst dich anschließend erneut mit deinen Zugangsdaten anmelden.',
      confirmLabel: 'Abmelden',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
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
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        if (showDivider) const Divider(height: 1, indent: 56),
      ],
    );
  }
}
