import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  /// The manifest element declaring [name], from its opening tag to its end.
  String component(String name) {
    final start = manifest.indexOf('android:name="$name"');
    expect(start, isNot(-1), reason: '$name is declared');
    final open = manifest.lastIndexOf('<', start);
    final tag = manifest.substring(open + 1).split(RegExp(r'\s')).first;
    final close = manifest.indexOf('</$tag>', start);
    return manifest.substring(open, close);
  }

  test('release manifest declares internet permission for Firebase auth', () {
    expect(manifest, contains('android.permission.INTERNET'));
  });

  group('auto-capture', () {
    test('notifications reach capture through Aiko\'s own listener', () {
      final listener = component('.CaptureNotificationListener');
      expect(
        listener,
        contains(
          'android:permission="android.permission.'
          'BIND_NOTIFICATION_LISTENER_SERVICE"',
        ),
      );
      // The plugin's listener broadcast every notification to any app.
      expect(manifest, isNot(contains('notification.listener.service')));
      final source = File(
        'android/app/src/main/kotlin/dev/pepo/aiko/'
        'CaptureNotificationListener.kt',
      ).readAsStringSync();
      expect(source, isNot(contains('sendBroadcast')));
    });

    test('the SMS receiver is off until capture switches it on', () {
      final receiver = component('.CaptureSmsReceiver');
      expect(receiver, contains('android:enabled="false"'));
      expect(
        receiver,
        contains('android:permission="android.permission.BROADCAST_SMS"'),
      );
      // Only the guarded receiver hands SMS to the plugin.
      expect(manifest, isNot(contains('IncomingSmsReceiver')));
    });
  });
}
