import 'package:aiko/app/aiko_app.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps profile theme preference to MaterialApp theme mode', () {
    expect(themeModeForPreferredTheme(PreferredTheme.system), ThemeMode.system);
    expect(themeModeForPreferredTheme(PreferredTheme.light), ThemeMode.light);
    expect(themeModeForPreferredTheme(PreferredTheme.dark), ThemeMode.dark);
  });
}
