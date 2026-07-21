import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../models/announcement.dart';
import '../../providers/api_providers.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_colors.dart';
import '../../utils/date_formatters.dart';
import '../../widgets/status_views.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  late Future<List<Announcement>> _future;
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<Announcement>> _load() => ref.read(announcementRepositoryProvider).latest();

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || text.length > AppConfig.maxAnnouncementLength) return;
    setState(() => _sending = true);
    try {
      await ref.read(announcementRepositoryProvider).send(text);
      _controller.clear();
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Ankündigungen')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Announcement>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingView(message: 'Ankündigungen werden geladen ...');
                }
                if (snapshot.hasError) {
                  return ErrorView(message: snapshot.error.toString(), onRetry: _refresh);
                }
                final announcements = snapshot.data ?? [];
                if (announcements.isEmpty) {
                  return const EmptyView(
                    icon: Icons.campaign_outlined,
                    title: 'Noch keine Ankündigungen vorhanden',
                    message: 'Neue Nachrichten erscheinen hier für alle Sanis.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: announcements.length,
                    itemBuilder: (context, index) {
                      final announcement = announcements[announcements.length - index - 1];
                      final mine = currentUser?.id == announcement.senderUserId;
                      return _AnnouncementBubble(announcement: announcement, mine: mine);
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: AppConfig.maxAnnouncementLength,
                      decoration: const InputDecoration(
                        hintText: 'Nachricht schreiben',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Senden',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementBubble extends StatelessWidget {
  const _AnnouncementBubble({required this.announcement, required this.mine});

  final Announcement announcement;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? AppColors.lightBlue : AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${announcement.senderName} · ${announcement.senderRole}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.mainText),
            ),
            const SizedBox(height: 6),
            Text(announcement.message),
            const SizedBox(height: 8),
            Text(
              DateFormatters.timestamp(announcement.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
