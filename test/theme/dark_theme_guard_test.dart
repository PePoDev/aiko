import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guard: screens and shared widgets must use `Theme.of(context)`
/// tokens for semantic colors, not hardcoded `AikoColors.*` constants.
///
/// Brand colors are exempt (they ARE the brand, in both light and dark mode):
///   - primaryBlue, deepBlue, softBlue, paleBlue
///   - successGreen, successGreenDark
///   - warningOrange, warningOrangeDark
///   - dangerRed, dangerRedDark
///   - premiumPurple, premiumPurpleDark
///   - analyticsTeal, analyticsTealDark
///   - white (on accent button backgrounds — semantic onPrimary)
///
/// Hardcoded scaffold/AppBar `appBackground` / `appBackgroundLight` are
/// also banned — let the theme apply via `scaffoldBackgroundColor`.
void main() {
  group('Dark theme static guard', () {
    final bannedColorTokens = <String>[
      'AikoColors.darkNavy',
      'AikoColors.neutralInk',
      'AikoColors.mutedText',
      'AikoColors.surfacePanel',
      'AikoColors.surfacePanelStrong',
      'AikoColors.surfacePanelDark',
      'AikoColors.surfacePanelDarkStrong',
      'AikoColors.border',
      'AikoColors.borderSubtle',
      'AikoColors.appBackground',
      'AikoColors.appBackgroundLight',
    ];

    final whitelistedFiles = <String>{
      // Brand-only file: gradients and accent colors live here
      'lib/theme/aiko_colors.dart',
      // Theme file: assigns colors to scheme tokens
      'lib/theme/aiko_theme.dart',
    };

    test('no banned color tokens in presentation/shared code', () async {
      final roots = [
        'lib/features',
        'lib/shared/widgets',
        'lib/app',
      ];
      final violations = <String>[];

      for (final root in roots) {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        await _scanDir(dir, bannedColorTokens, whitelistedFiles, violations);
      }

      expect(
        violations,
        isEmpty,
        reason:
            'These files use hardcoded semantic colors that will not '
            'adapt to dark mode. Use Theme.of(context).colorScheme.* '
            'tokens instead. See docs/superpowers/specs/2026-06-14-'
            'full-dark-theme-support-design.md for the mapping table.\n'
            'Violations:\n${violations.join("\n")}',
      );
    });
  });
}

Future<void> _scanDir(
  Directory dir,
  List<String> banned,
  Set<String> whitelist,
  List<String> violations,
) async {
  await for (final entity in dir.list(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    if (whitelist.contains(entity.path.replaceAll(r'\', '/'))) continue;

    final content = await entity.readAsString();
    final lines = const LineSplitter().convert(content);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Skip comment-only lines
      final trimmed = line.trim();
      if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

      for (final token in banned) {
        if (line.contains(token)) {
          violations.add(
            '${entity.path}:${i + 1}: $line',
          );
        }
      }
    }
  }
}
