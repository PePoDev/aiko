import 'package:aiko/app/aiko_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings omits retired planning screens', () {
    expect(
      aikoNavigationItems.map((item) => item.path),
      isNot(contains('/settings/pace')),
    );
    expect(
      aikoNavigationItems.map((item) => item.label),
      isNot(contains('Budget: Pace')),
    );
    expect(
      aikoNavigationItems.map((item) => item.path),
      isNot(contains('/settings/safe-to-spend')),
    );
    expect(
      aikoNavigationItems.map((item) => item.label),
      isNot(contains('Budget: Safe to Spend')),
    );
    expect(
      aikoNavigationItems.map((item) => item.path),
      isNot(contains('/settings/cash-flow-sankey')),
    );
    expect(
      aikoNavigationItems.map((item) => item.label),
      isNot(contains('Budget: Cash Flow (Sankey)')),
    );
    expect(
      aikoNavigationItems.map((item) => item.path),
      isNot(contains('/settings/cash-flow')),
    );
    expect(
      aikoNavigationItems.map((item) => item.label),
      isNot(contains('Budget: Cash Flow')),
    );
    expect(aikoNavigationItems.first.path, '/settings/chance-of-success');
  });
}
