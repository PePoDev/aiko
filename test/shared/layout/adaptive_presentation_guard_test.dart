import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guard: web, Android and iOS share one UI, so screens must not hard-
/// code phone-only or desktop-only presentation.
///
/// - Panels open with `showAikoSheet` (bottom sheet on phones, dialog on wide
///   screens), never `showModalBottomSheet` directly.
/// - Pages open with `openAikoPage` (full-screen route on phones, dialog on
///   wide screens) or a GoRouter route, never a hand-built `MaterialPageRoute`.
/// - Navigation chrome (tab bar, rail, sidebar) lives only in `lib/app/`,
///   built from `aikoPrimaryDestinations`.
///
/// See docs/design-system.md#web-and-mobile.
void main() {
  final rules = <({String token, String use, bool Function(String) allowed})>[
    (
      token: 'showModalBottomSheet',
      use: 'showAikoSheet (lib/shared/layout/adaptive_presentation.dart)',
      allowed: (path) => path.startsWith('lib/shared/layout/'),
    ),
    (
      token: 'MaterialPageRoute',
      use: 'openAikoPage (lib/shared/layout/adaptive_presentation.dart)',
      allowed: (path) => path.startsWith('lib/shared/layout/'),
    ),
    (
      token: 'CupertinoPageRoute',
      use: 'openAikoPage (lib/shared/layout/adaptive_presentation.dart)',
      allowed: (path) => path.startsWith('lib/shared/layout/'),
    ),
    for (final token in [
      'NavigationRail',
      'NavigationBar(',
      'BottomNavigationBar(',
    ])
      (
        token: token,
        use: 'aikoPrimaryDestinations (lib/app/aiko_navigation.dart)',
        allowed: (path) => path.startsWith('lib/app/'),
      ),
  ];

  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !file.path.endsWith('.g.dart'))
      .toList();

  test('finds the sources to scan', () {
    expect(sources, isNotEmpty);
  });

  for (final rule in rules) {
    test('${rule.token} is used only where both layouts are handled', () {
      final violations = <String>[];
      for (final file in sources) {
        final path = file.path.replaceAll(r'\', '/');
        if (rule.allowed(path)) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trimLeft();
          if (line.startsWith('//')) continue;
          if (line.contains(rule.token)) violations.add('$path:${i + 1}');
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Use ${rule.use} instead of ${rule.token}: $violations',
      );
    });
  }
}
