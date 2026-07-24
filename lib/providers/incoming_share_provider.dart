import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/sharing/incoming_share_service.dart';

export '../core/sharing/incoming_share_service.dart' show IncomingSharePayload;

final incomingShareServiceProvider = Provider<IncomingShareService>((ref) {
  final service = IncomingShareService();
  ref.onDispose(service.dispose);
  return service;
});

class IncomingShareController extends Notifier<IncomingSharePayload?> {
  @override
  IncomingSharePayload? build() => null;

  void set(IncomingSharePayload payload) {
    state = payload;
  }

  void consume(String id) {
    if (state?.id == id) state = null;
  }
}

final incomingShareProvider =
    NotifierProvider<IncomingShareController, IncomingSharePayload?>(
      IncomingShareController.new,
    );
