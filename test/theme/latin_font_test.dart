import 'dart:io';

import 'package:aiko/theme/aiko_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Latin text must look the same offline and on the first web load, so every
/// font the theme requests ships with the app and google_fonts never
/// downloads one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme fonts load from bundled assets, never the network', () async {
    final theme = AikoTypography.textTheme(Colors.black);
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
    // Fails when a requested font file is missing from the asset bundle.
    await GoogleFonts.pendingFonts();

    final families = <String?>{
      for (final style in [
        theme.displayLarge,
        theme.headlineLarge,
        theme.headlineMedium,
        theme.titleLarge,
        theme.titleMedium,
        theme.titleSmall,
        theme.bodyLarge,
        theme.bodyMedium,
        theme.bodySmall,
        theme.labelLarge,
        theme.labelMedium,
        theme.labelSmall,
      ])
        style?.fontFamily,
    };
    // google_fonts names a loaded font "<Family>_<variant>". A new weight
    // needs its file under assets/fonts/ and in pubspec.yaml.
    expect(families, {
      'HankenGrotesk_700',
      'Manrope_regular',
      'Manrope_500',
      'Manrope_700',
    });
  });

  test('bundled Latin fonts carry their license', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final fonts = RegExp(
      r'- (assets/fonts/(?:manrope|hanken_grotesk)/\S+\.ttf)',
    ).allMatches(pubspec).map((m) => m[1]!).toList();
    expect(fonts, hasLength(4));
    for (final font in fonts) {
      expect(File(font).existsSync(), isTrue, reason: font);
      expect(
        File('${File(font).parent.path}/OFL.txt').existsSync(),
        isTrue,
        reason: font,
      );
    }
  });
}
