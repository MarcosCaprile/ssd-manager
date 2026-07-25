import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android notification icon remains referenced by the manifest', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_icon'),
    );
    expect(
      File(
        'android/app/src/main/res/drawable/ic_stat_ssd_manager.xml',
      ).existsSync(),
      isTrue,
    );
  });
}
