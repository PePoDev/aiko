import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Thai text must render offline and on the first web load, so the Thai
/// fallback font ships with the app instead of being fetched at runtime.
void main() {
  test('Noto Sans Thai is bundled and used as the text fallback', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: NotoSansThai'));
    final assets = RegExp(
      r'asset: (assets/fonts/noto_sans_thai/\S+\.ttf)',
    ).allMatches(pubspec).map((m) => m[1]!).toList();
    expect(assets, isNotEmpty);
    for (final asset in assets) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
    expect(File('assets/fonts/noto_sans_thai/OFL.txt').existsSync(), isTrue);

    final typography = File(
      'lib/theme/aiko_typography.dart',
    ).readAsStringSync();
    expect(typography, contains("<String>['NotoSansThai']"));
  });
}
