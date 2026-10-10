import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// English and Thai must stay complete and in step: same keys, same
/// placeholders, real Thai text, and no strings the app no longer uses.
void main() {
  Map<String, dynamic> load(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  final en = load('en');
  final th = load('th');
  Iterable<String> keys(Map<String, dynamic> arb) =>
      arb.keys.where((key) => !key.startsWith('@'));

  // Values that are the same in both languages (brand names, symbols).
  const sameInBothLanguages = <String>{
    'aikoTab', // brand name
    'txReminderBody', // "{amount} · {type}": only placeholders
    'glossaryAprTerm', // "APR" is used as-is in Thai finance text
  };

  test('Thai has exactly the English keys', () {
    expect(keys(th).toSet(), keys(en).toSet());
  });

  test('Thai keeps every placeholder', () {
    final problems = <String>[];
    for (final key in keys(en)) {
      final meta = en['@$key'] as Map<String, dynamic>?;
      final placeholders =
          (meta?['placeholders'] as Map<String, dynamic>?)?.keys ?? const [];
      for (final name in placeholders) {
        if (!(th[key] as String? ?? '').contains('{$name')) {
          problems.add('$key: {$name}');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('Thai strings are translated', () {
    final thai = RegExp('[฀-๿]');
    final untranslated = [
      for (final key in keys(th))
        if (!sameInBothLanguages.contains(key) &&
            !thai.hasMatch(th[key] as String))
          key,
    ];
    expect(untranslated, isEmpty, reason: 'Translate into Thai: $untranslated');
  });

  // Code reads strings as `context.l10n.key`, through a local `l10n` (or
  // `strings`), or outside widgets as `currentL10n().key`.
  test('every string is used', () {
    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.contains('lib/l10n/app_localizations'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    final unused = [
      for (final key in keys(en))
        if (!RegExp(
          '(?:l10n|L10n\\(\\)|strings)\\s*\\.\\s*$key\\b',
        ).hasMatch(source))
          key,
    ];
    expect(unused, isEmpty, reason: 'Remove unused strings: $unused');
  });

  test('Android and iOS offer the same languages as the app', () {
    final languages = Directory('lib/l10n')
        .listSync()
        .map((file) => RegExp(r'app_(\w+)\.arb$').firstMatch(file.path))
        .whereType<RegExpMatch>()
        .map((match) => match[1]!)
        .toSet();
    final android = File(
      'android/app/src/main/res/xml/locales_config.xml',
    ).readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    for (final language in languages) {
      expect(android, contains('android:name="$language"'));
      expect(ios, contains('<string>$language</string>'));
    }
    expect(languages, {'en', 'th'});
  });
}
