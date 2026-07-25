import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/core/push/apns_token_waiter.dart';

void main() {
  test('waits until the APNs token becomes available', () async {
    var reads = 0;
    const waiter = ApnsTokenWaiter(maxAttempts: 3, interval: Duration.zero);

    final available = await waiter.wait(
      readToken: () async {
        reads++;
        return reads == 3 ? 'apns-token' : null;
      },
      delay: (_) async {},
    );

    expect(available, isTrue);
    expect(reads, 3);
  });

  test('stops after the configured number of attempts', () async {
    var reads = 0;
    const waiter = ApnsTokenWaiter(maxAttempts: 2, interval: Duration.zero);

    final available = await waiter.wait(
      readToken: () async {
        reads++;
        return null;
      },
      delay: (_) async {},
    );

    expect(available, isFalse);
    expect(reads, 2);
  });
}
