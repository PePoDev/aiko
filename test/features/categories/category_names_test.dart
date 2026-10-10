import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:aiko/features/categories/presentation/category_names.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));
  final thai = lookupAppLocalizations(const Locale('th'));
  final thaiScript = RegExp('[฀-๿]');

  test('every built-in category has an English and a Thai name', () {
    for (final category in CategoryDefaults.all) {
      expect(category.displayName(english), category.name);
      expect(
        thaiScript.hasMatch(category.displayName(thai)),
        isTrue,
        reason: category.name,
      );
    }
  });

  test('every built-in group has an English and a Thai name', () {
    for (final group in CategoryGroupDefaults.all) {
      expect(group.displayName(english), group.name);
      expect(
        thaiScript.hasMatch(group.displayName(thai)),
        isTrue,
        reason: group.name,
      );
    }
  });

  test('a per-user clone of a built-in category is translated', () {
    final clone = CategoryDefaults.cloneForUser(
      userId: 'u1',
      template: CategoryDefaults.byId[CategoryDefaults.coffeeId]!,
    );
    expect(clone.displayName(thai), 'กาแฟ');
  });

  test('a renamed built-in category keeps the user\'s name', () {
    final renamed = CategoryDefaults.byId[CategoryDefaults.coffeeId]!.copyWith(
      name: 'Morning latte',
    );
    expect(renamed.displayName(thai), 'Morning latte');
  });

  test('an unchanged translated name is stored as the template name', () {
    expect(
      storedCategoryName(original: 'Coffee', shown: 'กาแฟ', edited: 'กาแฟ'),
      'Coffee',
    );
    expect(
      storedCategoryName(original: 'Coffee', shown: 'กาแฟ', edited: 'ลาเต้'),
      'ลาเต้',
    );
  });
}
