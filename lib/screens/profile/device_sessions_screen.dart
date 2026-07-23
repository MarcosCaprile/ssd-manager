import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/device_session.dart';
import '../../providers/api_providers.dart';
import '../../utils/date_formatters.dart';
import '../../utils/user_error_message.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_views.dart';

class DeviceSessionsScreen extends ConsumerStatefulWidget {
  const DeviceSessionsScreen({super.key});

  @override
  ConsumerState<DeviceSessionsScreen> createState() =>
      _DeviceSessionsScreenState();
}

class _DeviceSessionsScreenState extends ConsumerState<DeviceSessionsScreen> {
  late Future<List<DeviceSession>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DeviceSession>> _load() {
    return ref.read(userRepositoryProvider).devices();
  }

  Future<void> _refresh({bool preserveOnError = false}) async {
    if (preserveOnError) {
      try {
        final devices = await _load();
        if (mounted) setState(() => _future = Future.value(devices));
      } catch (_) {
        // Die Abmeldung war erfolgreich; ein fehlgeschlagenes Nachladen
        // ändert dieses Ergebnis nicht.
      }
      return;
    }
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Angemeldete Geräte')),
      body: FutureBuilder<List<DeviceSession>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const DelayedLoadingView(
              message: 'Geräte werden geladen ...',
            );
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error, onRetry: _refresh);
          }
          final devices = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (devices.isEmpty)
                  const EmptyView(
                    icon: Icons.devices_outlined,
                    title: 'Keine aktiven Geräte',
                    message:
                        'Aktive Anmeldungen werden hier automatisch angezeigt.',
                  )
                else ...[
                  for (final device in devices)
                    _DeviceCard(
                      device: device,
                      onRevoke: device.isCurrent ? null : () => _revoke(device),
                    ),
                  if (devices.where((device) => !device.isCurrent).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton.icon(
                        onPressed: _revokeOthers,
                        icon: const Icon(Icons.phonelink_erase_outlined),
                        label: const Text('Alle anderen Geräte abmelden'),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _revoke(DeviceSession device) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Gerät abmelden?',
      message: 'Die Sitzung auf „${device.deviceName}“ wird widerrufen.',
      confirmLabel: 'Abmelden',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final succeeded = await _runMutation(
      () => ref.read(userRepositoryProvider).revokeDevice(device.id),
    );
    if (succeeded) await _refresh(preserveOnError: true);
  }

  Future<void> _revokeOthers() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Andere Geräte abmelden?',
      message: 'Alle anderen aktiven Sitzungen werden widerrufen.',
      confirmLabel: 'Abmelden',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final succeeded = await _runMutation(
      () => ref.read(userRepositoryProvider).revokeOtherDevices(),
    );
    if (succeeded) await _refresh(preserveOnError: true);
  }

  Future<bool> _runMutation(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gerät wurde abgemeldet.')),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
      return false;
    }
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onRevoke});

  final DeviceSession device;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          device.platform == 'ios' ? Icons.phone_iphone : Icons.phone_android,
        ),
        title: Text(device.deviceName),
        subtitle: Text(
          '${device.platform} · ${device.deviceModel}\n'
          'Login: ${DateFormatters.timestamp(device.createdAt)}\n'
          'Zuletzt aktiv: ${DateFormatters.timestamp(device.lastActiveAt)}',
        ),
        isThreeLine: true,
        trailing: device.isCurrent
            ? const Chip(label: Text('Dieses Gerät'))
            : IconButton(
                tooltip: 'Gerät abmelden',
                onPressed: onRevoke,
                icon: const Icon(Icons.logout),
              ),
      ),
    );
  }
}
