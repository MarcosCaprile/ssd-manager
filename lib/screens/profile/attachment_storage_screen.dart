import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/attachment_storage.dart';
import '../../providers/api_providers.dart';
import '../../utils/date_formatters.dart';
import '../../utils/user_error_message.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/status_views.dart';

class AttachmentStorageScreen extends ConsumerStatefulWidget {
  const AttachmentStorageScreen({super.key});

  @override
  ConsumerState<AttachmentStorageScreen> createState() =>
      _AttachmentStorageScreenState();
}

class _AttachmentStorageScreenState
    extends ConsumerState<AttachmentStorageScreen> {
  String _sort = 'date_desc';
  late Future<AttachmentStorageSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AttachmentStorageSummary> _load() {
    return ref.read(userRepositoryProvider).attachmentStorage(sort: _sort);
  }

  Future<void> _refresh({bool preserveOnError = false}) async {
    if (preserveOnError) {
      try {
        final storage = await _load();
        if (mounted) setState(() => _future = Future.value(storage));
      } catch (_) {
        // Das Löschen bleibt erfolgreich, auch wenn die aktualisierte
        // Speicherübersicht erst beim nächsten Öffnen geladen werden kann.
      }
      return;
    }
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _delete(StoredAttachment attachment) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Datei löschen?',
      message:
          '„${attachment.fileName}“ wird dauerhaft aus der Cloud gelöscht. Die Ankündigung bleibt erhalten und zeigt, dass der Inhalt gelöscht wurde.',
      confirmLabel: 'Löschen',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(userRepositoryProvider).deleteAttachment(attachment.id);
      ref.read(announcementRepositoryProvider).evictAttachment(attachment.id);
      ref.read(announcementRevisionProvider.notifier).bump();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Datei wurde gelöscht.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
      return;
    }
    await _refresh(preserveOnError: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud-Speicher')),
      body: FutureBuilder<AttachmentStorageSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const DelayedLoadingView(
              message: 'Dateien werden geladen ...',
            );
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error, onRetry: _refresh);
          }
          final storage = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Speicherübersicht',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: storage.usedFraction,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_formatBytes(storage.usedBytes)} von ${_formatBytes(storage.limitBytes)} belegt',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sort,
                      decoration: const InputDecoration(
                        labelText: 'Sortierung',
                        prefixIcon: Icon(Icons.sort),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'date_desc',
                          child: Text('Neueste zuerst'),
                        ),
                        DropdownMenuItem(
                          value: 'date_asc',
                          child: Text('Älteste zuerst'),
                        ),
                        DropdownMenuItem(
                          value: 'size_desc',
                          child: Text('Größte zuerst'),
                        ),
                        DropdownMenuItem(
                          value: 'size_asc',
                          child: Text('Kleinste zuerst'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null || value == _sort) return;
                        setState(() {
                          _sort = value;
                          _future = _load();
                        });
                      },
                    ),
                  ),
                ),
                if (storage.attachments.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.cloud_done_outlined,
                      title: 'Kein Speicher belegt',
                      message:
                          'Deine versendeten Bilder und Dateien erscheinen hier.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList.separated(
                      itemCount: storage.attachments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final attachment = storage.attachments[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              attachment.isImage
                                  ? Icons.image_outlined
                                  : Icons.insert_drive_file_outlined,
                            ),
                            title: Text(
                              attachment.fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_formatBytes(attachment.sizeBytes)} · '
                              '${DateFormatters.timestamp(attachment.createdAt)}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Datei löschen',
                              onPressed: () => _delete(attachment),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
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
