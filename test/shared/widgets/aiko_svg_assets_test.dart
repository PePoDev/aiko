import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const requiredIcons = [
    'home',
    'transactions',
    'budget',
    'insights',
    'aiko',
    'account',
    'bank',
    'credit_card',
    'wallet',
    'category',
    'receipt',
    'search_filter',
    'goal',
    'cash_flow',
    'debt',
    'loan',
    'portfolio',
    'tax',
    'calculator',
    'travel',
    'security',
    'notification',
  ];

  for (final icon in requiredIcons) {
    testWidgets('assets/icons/aiko_$icon.svg is a reusable svg asset', (
      tester,
    ) async {
      final content = await rootBundle.loadString(
        'assets/icons/aiko_$icon.svg',
      );

      expect(content.trimLeft(), startsWith('<svg'));
      expect(content, contains('viewBox="0 0 24 24"'));
      expect(content, contains('currentColor'));
    });
  }
}
