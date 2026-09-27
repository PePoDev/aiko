import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release manifest declares internet permission for Firebase auth', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.INTERNET'));
  });
}
