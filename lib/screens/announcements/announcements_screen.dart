import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_config.dart';
import '../../models/announcement.dart';
import '../../models/user.dart';
import '../../providers/api_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incoming_share_provider.dart';
import '../../repositories/announcement_repository.dart';
import '../../themes/app_colors.dart';
import '../../utils/date_formatters.dart';
import '../../utils/user_error_message.dart';
import '../../widgets/status_views.dart';
import 'announcement_attachment_views.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key, this.active = true});

  final bool active;

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  static const _maxAttachments = 4;
  static const _maxAttachmentBytes = 8 * 1024 * 1024;

  late Future<List<Announcement>> _future;
  final _controller = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<_PendingAttachment> _pending = [];
  List<Announcement> _items = [];
  bool _sending = false;
  bool _refreshing = false;
  bool _refreshQueued = false;
  String? _scheduledIncomingShareId;

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

  Future<List<Announcement>> _load() async {
    final items = await ref.read(announcementRepositoryProvider).latest();
    _items = items;
    ref.read(announcementFeedProvider.notifier).replace(items);
    return items;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _refreshPreservingContent() async {
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshQueued = false;
        try {
          final items = await _load();
          if (mounted) {
            setState(() => _future = Future.value(List.unmodifiable(items)));
          }
        } catch (_) {
          // Bereits sichtbare Ankündigungen bleiben erhalten. Der nächste
          // Push, Live-Abgleich oder Pull-to-refresh versucht es erneut.
        }
      } while (_refreshQueued && mounted);
    } finally {
      _refreshing = false;
    }
  }

  List<Announcement> _withAnnouncement(
    List<Announcement> announcements,
    Announcement announcement,
  ) {
    final byId = {
      for (final item in announcements) item.id: item,
      announcement.id: announcement,
    };
    final result = byId.values.toList()
      ..sort((a, b) {
        final timeComparison = a.createdAt.compareTo(b.createdAt);
        return timeComparison != 0 ? timeComparison : a.id.compareTo(b.id);
      });
    return result;
  }

  bool _isSameLocalDay(DateTime first, DateTime second) {
    final a = first.toLocal();
    final b = second.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildAnnouncementItem({
    required Announcement announcement,
    required Announcement? previous,
    required User? currentUser,
  }) {
    final startsNewDay =
        previous == null ||
        !_isSameLocalDay(previous.createdAt, announcement.createdAt);
    final showSender =
        startsNewDay ||
        previous.isSystem ||
        announcement.isSystem ||
        previous.senderUserId != announcement.senderUserId;
    final bubble = announcement.isSystem
        ? _SystemAnnouncementBubble(announcement: announcement)
        : _AnnouncementBubble(
            announcement: announcement,
            mine: currentUser?.id == announcement.senderUserId,
            showSender: showSender,
            repository: ref.read(announcementRepositoryProvider),
          );
    return Column(
      key: ValueKey(announcement.id),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (startsNewDay) _ChatDayDivider(createdAt: announcement.createdAt),
        bubble,
      ],
    );
  }

  Future<void> _refreshAfterSend() async {
    if (_refreshQueued) {
      await _refreshPreservingContent();
    }
  }

  Future<void> _setSentAnnouncement(Announcement sent) async {
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _pending.clear();
      _items = _withAnnouncement(_items, sent);
      _future = Future.value(List.unmodifiable(_items));
    });
    await _refreshAfterSend();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _pending.isEmpty) ||
        text.length > AppConfig.maxAnnouncementLength) {
      return;
    }
    setState(() => _sending = true);
    try {
      final repository = ref.read(announcementRepositoryProvider);
      for (final pending in _pending) {
        if (pending.attachmentId != null) continue;
        final uploaded = await repository.uploadAttachment(
          fileName: pending.fileName,
          bytes: pending.bytes,
        );
        pending.attachmentId = uploaded.id;
      }
      final sent = await repository.send(
        message: text,
        attachmentIds: _pending
            .map((item) => item.attachmentId)
            .whereType<int>()
            .toList(),
      );
      await _setSentAnnouncement(sent);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(announcementRevisionProvider, (previous, next) {
      if (previous != next) _refreshPreservingContent();
    });
    ref.listen<List<Announcement>?>(announcementFeedProvider, (previous, next) {
      if (next == null || identical(previous, next)) return;
      _items = next;
      setState(() => _future = Future.value(next));
    });
    final incomingShare = ref.watch(incomingShareProvider);
    if (widget.active && incomingShare != null) {
      _scheduleIncomingShare(incomingShare);
    }
    final currentUser = ref.watch(authControllerProvider).user;
    final canSend =
        !_sending &&
        (_controller.text.trim().isNotEmpty || _pending.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Ankündigungen')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Announcement>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const DelayedLoadingView(
                    message: 'Ankündigungen werden geladen ...',
                  );
                }
                if (snapshot.hasError) {
                  return ErrorView(error: snapshot.error, onRetry: _refresh);
                }
                final announcements = snapshot.data ?? [];
                if (announcements.isEmpty) {
                  return const EmptyView(
                    icon: Icons.campaign_outlined,
                    title: 'Noch keine Ankündigungen vorhanden',
                    message:
                        'Neue Nachrichten erscheinen hier für alle Personen der Schule.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    itemCount: announcements.length,
                    itemBuilder: (context, index) {
                      final originalIndex = announcements.length - index - 1;
                      final announcement = announcements[originalIndex];
                      final previous = originalIndex == 0
                          ? null
                          : announcements[originalIndex - 1];
                      return _buildAnnouncementItem(
                        announcement: announcement,
                        previous: previous,
                        currentUser: currentUser,
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_pending.isNotEmpty)
                      _PendingAttachmentStrip(
                        attachments: _pending,
                        enabled: !_sending,
                        onRemove: (item) {
                          setState(() => _pending.remove(item));
                        },
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Foto oder Datei anhängen',
                          onPressed: _sending || _pending.length >= 4
                              ? null
                              : _chooseAttachment,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !_sending,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: AppConfig.maxAnnouncementLength,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Nachricht',
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          tooltip: 'Senden',
                          onPressed: canSend ? _send : null,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseAttachment() async {
    final source = await showModalBottomSheet<_AttachmentSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Foto auswählen'),
              subtitle: const Text('JPG, PNG, WEBP oder HEIC'),
              onTap: () => Navigator.of(context).pop(_AttachmentSource.photo),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Datei auswählen'),
              subtitle: const Text('PDF, Text, Word, Excel oder PowerPoint'),
              onTap: () => Navigator.of(context).pop(_AttachmentSource.file),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      if (source == _AttachmentSource.photo) {
        final files = await _imagePicker.pickMultiImage(
          imageQuality: 88,
          maxWidth: 2400,
        );
        await _addFiles(files);
      } else {
        const typeGroup = XTypeGroup(
          label: 'Unterstützte Dateien',
          extensions: [
            'pdf',
            'txt',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'ppt',
            'pptx',
          ],
          uniformTypeIdentifiers: [
            'com.adobe.pdf',
            'public.plain-text',
            'com.microsoft.word.doc',
            'org.openxmlformats.wordprocessingml.document',
            'com.microsoft.excel.xls',
            'org.openxmlformats.spreadsheetml.sheet',
            'com.microsoft.powerpoint.ppt',
            'org.openxmlformats.presentationml.presentation',
          ],
        );
        await _addFiles(await openFiles(acceptedTypeGroups: [typeGroup]));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    }
  }

  Future<void> _addFiles(List<XFile> files) async {
    var rejectedForSize = false;
    final remaining = _maxAttachments - _pending.length;
    for (final file in files.take(remaining)) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > _maxAttachmentBytes) {
        rejectedForSize = true;
        continue;
      }
      final extension = file.name.split('.').last.toLowerCase();
      final previewable = const [
        'jpg',
        'jpeg',
        'png',
        'webp',
      ].contains(extension);
      _pending.add(
        _PendingAttachment(
          fileName: file.name,
          bytes: bytes,
          isImage: previewable,
        ),
      );
    }
    if (!mounted) return;
    setState(() {});
    if (files.length > remaining) {
      _showMessage('Pro Nachricht sind höchstens vier Anhänge möglich.');
    } else if (rejectedForSize) {
      _showMessage('Dateien müssen zwischen 1 Byte und 8 MB groß sein.');
    }
  }

  void _scheduleIncomingShare(IncomingSharePayload payload) {
    if (_scheduledIncomingShareId == payload.id) return;
    _scheduledIncomingShareId = payload.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final sharedFiles = payload.files
            .map((item) => XFile(item.path, name: item.fileName))
            .toList();
        if (sharedFiles.isNotEmpty) {
          await _addFiles(sharedFiles);
        }
        if (payload.text.isNotEmpty && mounted) {
          final current = _controller.text.trim();
          _controller.text = current.isEmpty
              ? payload.text
              : '$current\n${payload.text}';
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
          setState(() {});
        }
      } catch (error) {
        if (mounted) {
          _showMessage(userErrorMessage(error));
        }
      } finally {
        if (mounted) {
          ref.read(incomingShareProvider.notifier).consume(payload.id);
        }
        _scheduledIncomingShareId = null;
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ChatDayDivider extends StatelessWidget {
  const _ChatDayDivider({required this.createdAt});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 5),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              DateFormatters.chatDayLabel(createdAt),
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AttachmentSource { photo, file }

class _PendingAttachment {
  _PendingAttachment({
    required this.fileName,
    required this.bytes,
    required this.isImage,
  });

  final String fileName;
  final Uint8List bytes;
  final bool isImage;
  int? attachmentId;
}

class _PendingAttachmentStrip extends StatelessWidget {
  const _PendingAttachmentStrip({
    required this.attachments,
    required this.enabled,
    required this.onRemove,
  });

  final List<_PendingAttachment> attachments;
  final bool enabled;
  final ValueChanged<_PendingAttachment> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 7),
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final item = attachments[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: item.isImage
                    ? Image.memory(item.bytes, fit: BoxFit.cover)
                    : Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.insert_drive_file_outlined),
                            const SizedBox(height: 3),
                            Text(
                              item.fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
              ),
              Positioned(
                top: -5,
                right: -5,
                child: IconButton.filled(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 24,
                    height: 24,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: '${item.fileName} entfernen',
                  onPressed: enabled ? () => onRemove(item) : null,
                  icon: const Icon(Icons.close, size: 15),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnnouncementBubble extends StatelessWidget {
  const _AnnouncementBubble({
    required this.announcement,
    required this.mine,
    required this.showSender,
    required this.repository,
  });

  final Announcement announcement;
  final bool mine;
  final bool showSender;
  final AnnouncementRepository repository;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: EdgeInsets.only(
          top: showSender ? 7 : 2,
          bottom: 1,
          left: mine ? 40 : 0,
          right: mine ? 0 : 40,
        ),
        padding: const EdgeInsets.fromLTRB(9, 7, 9, 5),
        decoration: BoxDecoration(
          color: mine
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSender) ...[
              Text(
                announcement.senderName,
                style: TextStyle(
                  color: _senderColor(scheme, announcement.senderUserId),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                UserRole.fromJson(announcement.senderRole).label,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 4),
            ],
            for (
              var index = 0;
              index < announcement.attachments.length;
              index++
            ) ...[
              AnnouncementAttachmentView(
                key: ValueKey(announcement.attachments[index].id),
                attachment: announcement.attachments[index],
                repository: repository,
              ),
              if (index < announcement.attachments.length - 1)
                const SizedBox(height: 5),
            ],
            if (announcement.attachments.isNotEmpty &&
                announcement.message.isNotEmpty)
              const SizedBox(height: 5),
            if (announcement.message.isNotEmpty)
              Text(announcement.message, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  DateFormatters.chatTimestamp(announcement.createdAt),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _senderColor(ColorScheme scheme, int id) {
    final colors = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
    ];
    return colors[id.abs() % colors.length];
  }
}

class _SystemAnnouncementBubble extends StatelessWidget {
  const _SystemAnnouncementBubble({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.error, width: 1.4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sick_outlined, color: scheme.error, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Systemnachricht',
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    announcement.message,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormatters.chatTimestamp(announcement.createdAt),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
