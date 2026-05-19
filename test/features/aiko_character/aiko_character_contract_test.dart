import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('character brief captures data-first and warning requirements', () {
    final brief = File(
      'specs/002-aiko-product-expansion/aiko-character-brief.md',
    ).readAsStringSync();

    expect(brief, contains('Data first'));
    expect(brief, contains('Hide and reduced-visibility controls'));
    expect(brief, contains('Serious financial warnings'));
    expect(brief, contains('Avoid'));
  });
}
