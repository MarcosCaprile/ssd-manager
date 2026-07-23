import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/announcement.dart';
import '../../repositories/announcement_repository.dart';
import '../../utils/user_error_message.dart';

class AnnouncementAttachmentView extends StatefulWidget {
  const AnnouncementAttachmentView({
    super.key,
    required this.attachment,
    required this.repository,
  });

  final AnnouncementAttachment attachment;
  final AnnouncementRepository repository;

  @override
  State<AnnouncementAttachmentView> createState() =>
      _AnnouncementAttachmentViewState();
}

class _AnnouncementAttachmentViewState
    extends State<AnnouncementAttachmentView> {
  Future<Uint8List>? _imageFuture;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.isImage) {
      _imageFuture = _loadBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.attachment.isImage) {
      return _FileAttachment(
        attachment: widget.attachment,
        loadBytes: _loadBytes,
      );
    }
    return FutureBuilder<Uint8List>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AttachmentError(onRetry: _openImage);
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 220,
            height: 140,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return Semantics(
          button: true,
          label: 'Foto ${widget.attachment.fileName} im Vollbild öffnen',
          child: InkWell(
            onTap: () => _showImage(snapshot.data!),
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                snapshot.data!,
                width: 230,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _AttachmentError(onRetry: _openImage),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List> _loadBytes() {
    return widget.repository.attachmentBytes(widget.attachment.id);
  }

  Future<void> _openImage() async {
    final next = _loadBytes();
    setState(() => _imageFuture = next);
    try {
      _showImage(await next);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    }
  }

  void _showImage(Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenImage(
          bytes: bytes,
          fileName: widget.attachment.fileName,
        ),
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  const _FileAttachment({required this.attachment, required this.loadBytes});

  final AnnouncementAttachment attachment;
  final Future<Uint8List> Function() loadBytes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: const Icon(Icons.insert_drive_file_outlined),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatAttachmentSize(attachment.sizeBytes),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    try {
      final data = await loadBytes();
      final directory = await getTemporaryDirectory();
      final safeName = attachment.fileName.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );
      final file = File('${directory.path}/ssd-${attachment.id}-$safeName');
      await file.writeAsBytes(data, flush: true);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Die Datei konnte nicht geöffnet werden.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    }
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(fileName, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(80),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text(
              'Dieses Bild kann nicht angezeigt werden.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentError extends StatelessWidget {
  const _AttachmentError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onRetry,
      child: Container(
        width: 220,
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(height: 4),
            const Text('Bild erneut laden'),
          ],
        ),
      ),
    );
  }
}

String formatAttachmentSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
  return '$bytes B';
}
