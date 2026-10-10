import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guard: user-facing text comes from `context.l10n` (English and
/// Thai ARB files in lib/l10n/), never a string literal. Catches literals
/// passed to `Text` and to common text parameters. Brand names and other
/// deliberate exceptions carry a `// l10n-ignore` comment on the same line.
void main() {
  final textArgument = RegExp(
    r'''(?:\bText\(\s*|\b(?:label|labelText|hintText|helperText|tooltip|title|subtitle|message|semanticLabel|semanticsLabel|errorText|prefixText|suffixText|description|actionLabel|emptyMessage|confirmLabel|heading|caption)\s*:\s*)(?:const\s+)?(['"])((?:(?!\1).)*)\1''',
  );
  final interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');
  final letters = RegExp('[A-Za-z]');

  test('no hard-coded user-facing strings', () {
    final violations = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.contains('/l10n/'))
        .where((file) => !file.path.endsWith('.g.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      final lines = source.split('\n');
      for (final match in textArgument.allMatches(source)) {
        final text = match[2]!.replaceAll(interpolation, '');
        if (!letters.hasMatch(text)) continue;
        final line = source.substring(0, match.start).split('\n').length;
        final endLine = source.substring(0, match.end).split('\n').length;
        final ignored = lines
            .sublist(line - 1, endLine)
            .any((l) => l.contains('// l10n-ignore'));
        if (ignored) continue;
        violations.add(
          '${file.path.replaceAll(r'\', '/')}:$line ${match[0]!.trim()}',
        );
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Move these strings to lib/l10n/app_en.arb and app_th.arb '
          '(${violations.length}):\n${violations.join('\n')}',
    );
  });
}
