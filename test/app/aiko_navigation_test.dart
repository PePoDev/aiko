import 'package:aiko/app/aiko_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings omits the retired Pace Overview', () {
    expect(
      aikoNavigationItems.map((item) => item.path),
      isNot(contains('/settings/pace')),
    );
    expect(
      aikoNavigationItems.map((item) => item.label),
      isNot(contains('Budget: Pace')),
    );
    expect(aikoNavigationItems.first.path, '/settings/safe-to-spend');
  });
}
