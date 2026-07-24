import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
    if (widget.attachment.isImage && !widget.attachment.isDeleted) {
      _imageFuture = _loadBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachment.isDeleted) {
      return Text(
        'Dieser Inhalt wurde gelöscht.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
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
        return Stack(
          children: [
            Semantics(
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
            ),
            Positioned(
              right: 5,
              top: 5,
              child: _ShareButton(
                tooltip: 'Foto teilen',
                onPressed: (origin) => _shareBytes(
                  context,
                  bytes: snapshot.data!,
                  fileName: widget.attachment.fileName,
                  mimeType: widget.attachment.mimeType,
                  uniqueId: widget.attachment.id,
                  shareOrigin: origin,
                ),
              ),
            ),
          ],
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
          mimeType: widget.attachment.mimeType,
          attachmentId: widget.attachment.id,
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
            _ShareButton(
              tooltip: 'Datei teilen',
              compact: true,
              onPressed: (origin) async {
                try {
                  final bytes = await loadBytes();
                  if (!context.mounted) return;
                  await _shareBytes(
                    context,
                    bytes: bytes,
                    fileName: attachment.fileName,
                    mimeType: attachment.mimeType,
                    uniqueId: attachment.id,
                    shareOrigin: origin,
                  );
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(userErrorMessage(error))),
                    );
                  }
                }
              },
            ),
            const SizedBox(width: 2),
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

class _FullScreenImage extends StatefulWidget {
  const _FullScreenImage({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.attachmentId,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final int attachmentId;

  @override
  State<_FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<_FullScreenImage> {
  final _transformationController = TransformationController();
  bool _showChrome = true;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showChrome
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.72),
              foregroundColor: Colors.white,
              title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
              actions: [
                Builder(
                  builder: (buttonContext) => IconButton(
                    tooltip: 'Foto teilen',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () {
                      final box =
                          buttonContext.findRenderObject() as RenderBox?;
                      final origin = box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size;
                      _shareBytes(
                        context,
                        bytes: widget.bytes,
                        fileName: widget.fileName,
                        mimeType: widget.mimeType,
                        uniqueId: widget.attachmentId,
                        shareOrigin: origin,
                      );
                    },
                  ),
                ),
              ],
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showChrome = !_showChrome),
          onDoubleTap: () {
            final currentScale = _transformationController.value
                .getMaxScaleOnAxis();
            _transformationController.value = currentScale > 1
                ? Matrix4.identity()
                : (Matrix4.identity()..scaleByDouble(2, 2, 2, 1));
          },
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1,
            maxScale: 6,
            boundaryMargin: const EdgeInsets.all(160),
            clipBehavior: Clip.none,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Image.memory(
                widget.bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Text(
                    'Dieses Bild kann nicht angezeigt werden.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.tooltip,
    required this.onPressed,
    this.compact = false,
  });

  final String tooltip;
  final Future<void> Function(Rect? origin) onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) => Material(
        color: compact
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.64),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          visualDensity: compact ? VisualDensity.compact : null,
          iconSize: compact ? 18 : 20,
          color: compact
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : Colors.white,
          icon: const Icon(Icons.share_outlined),
          onPressed: () {
            final box = buttonContext.findRenderObject() as RenderBox?;
            final origin = box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size;
            onPressed(origin);
          },
        ),
      ),
    );
  }
}

Future<void> _shareBytes(
  BuildContext context, {
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  required int uniqueId,
  required Rect? shareOrigin,
}) async {
  try {
    final directory = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${directory.path}/ssd-share-$uniqueId-$safeName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType, name: fileName)],
        fileNameOverrides: [fileName],
        subject: 'SSD Manager – $fileName',
        sharePositionOrigin: shareOrigin,
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
    }
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
