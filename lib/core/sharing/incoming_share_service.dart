import 'dart:async';
import 'dart:io';

import 'package:share_handler/share_handler.dart';

class IncomingSharedFile {
  const IncomingSharedFile({
    required this.path,
    required this.fileName,
    required this.isImage,
  });

  final String path;
  final String fileName;
  final bool isImage;
}

class IncomingSharePayload {
  const IncomingSharePayload({
    required this.id,
    required this.text,
    required this.files,
  });

  final String id;
  final String text;
  final List<IncomingSharedFile> files;

  bool get isEmpty => text.isEmpty && files.isEmpty;
}

class IncomingShareService {
  final _controller = StreamController<IncomingSharePayload>.broadcast();
  StreamSubscription<SharedMedia>? _subscription;
  Future<void>? _initialization;

  Stream<IncomingSharePayload> get shares => _controller.stream;

  Future<void> initialize() {
    final existing = _initialization;
    if (existing != null) return existing;
    final operation = _initialize();
    _initialization = operation;
    return operation;
  }

  Future<void> _initialize() async {
    final handler = ShareHandlerPlatform.instance;
    _subscription ??= handler.sharedMediaStream.listen(
      _emit,
      onError: (_) {
        // Incoming share failures must not affect normal app startup.
      },
    );
    try {
      final initial = await handler.getInitialSharedMedia();
      if (initial != null) _emit(initial);
      await handler.resetInitialSharedMedia();
    } catch (_) {
      // Android/iOS without a configured share target still starts normally.
    }
  }

  void _emit(SharedMedia media) {
    final payload = _convert(media);
    if (!payload.isEmpty) _controller.add(payload);
  }

  IncomingSharePayload _convert(SharedMedia media) {
    final files = <IncomingSharedFile>[];
    for (final attachment in media.attachments ?? const []) {
      if (attachment == null || attachment.path.trim().isEmpty) continue;
      final normalizedPath = attachment.path.startsWith('file://')
          ? Uri.parse(attachment.path).toFilePath()
          : attachment.path;
      final fileName = File(normalizedPath).uri.pathSegments.isEmpty
          ? 'Anhang'
          : File(normalizedPath).uri.pathSegments.last;
      files.add(
        IncomingSharedFile(
          path: normalizedPath,
          fileName: Uri.decodeComponent(fileName),
          isImage: attachment.type == SharedAttachmentType.image,
        ),
      );
    }
    return IncomingSharePayload(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: (media.content ?? '').trim(),
      files: List.unmodifiable(files),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
