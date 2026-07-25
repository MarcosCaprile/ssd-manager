class ApnsTokenWaiter {
  const ApnsTokenWaiter({
    this.maxAttempts = 20,
    this.interval = const Duration(milliseconds: 250),
  });

  final int maxAttempts;
  final Duration interval;

  Future<bool> wait({
    required Future<String?> Function() readToken,
    Future<void> Function(Duration) delay = Future<void>.delayed,
  }) async {
    final attempts = maxAttempts < 1 ? 1 : maxAttempts;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final token = await readToken();
        if (token != null && token.trim().isNotEmpty) return true;
      } catch (_) {
        // APNs registration is asynchronous. Retry within the bounded window.
      }
      if (attempt + 1 < attempts) await delay(interval);
    }
    return false;
  }
}
