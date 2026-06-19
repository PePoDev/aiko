import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const requiredIcons = [
    'aiko',
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

  testWidgets('assets/icons/aiko_title.svg is a brand title wordmark asset', (
    tester,
  ) async {
    final content = await rootBundle.loadString('assets/icons/aiko_title.svg');

    expect(content.trimLeft(), startsWith('<svg'));
    expect(content, contains('viewBox="0 0 320 96"'));
    expect(content, contains('<title>Aiko</title>'));
    expect(content, contains('#2563EB'));
  });
}
