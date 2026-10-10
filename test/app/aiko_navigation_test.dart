import 'package:aiko/app/aiko_navigation.dart';
import 'package:aiko/app/app_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Set<String> _routerPaths() {
  final paths = <String>{};
  void visit(List<RouteBase> routes, String parent) {
    for (final route in routes) {
      var base = parent;
      if (route is GoRoute) {
        base = route.path.startsWith('/')
            ? route.path
            : '${parent == '/' ? '' : parent}/${route.path}';
        paths.add(base);
      }
      visit(route.routes, base);
    }
  }

  visit(createAikoRouter().configuration.routes, '');
  return paths;
}

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

  group('one navigation for web and mobile', () {
    final primaryPaths = aikoPrimaryDestinations.map((d) => d.path).toList();

    test('the phone bar shows exactly the sidebar destinations', () {
      expect(aikoBottomBarPaths.toSet(), primaryPaths.toSet());
      expect(aikoBottomBarPaths, hasLength(primaryPaths.length));
    });

    test('every destination and tool is a registered route', () {
      final routes = _routerPaths();
      for (final path in [
        ...primaryPaths,
        for (final tool in aikoNavigationItems) tool.path,
      ]) {
        expect(routes, contains(path), reason: '$path has no GoRoute');
      }
    });

    test('paths are unique', () {
      final all = [
        ...primaryPaths,
        for (final tool in aikoNavigationItems) tool.path,
      ];
      expect(all.toSet(), hasLength(all.length));
    });
  });

  group('aikoSelectedPath', () {
    const bar = aikoBottomBarPaths;

    test('matches a destination and its sub-paths', () {
      expect(aikoSelectedPath('/accounts', bar), '/accounts');
      expect(aikoSelectedPath('/aiko/chat', bar), '/aiko');
    });

    test('does not match a path that only shares a prefix', () {
      expect(aikoSelectedPath('/transaction-rules', ['/transaction']), '/home');
    });

    test('secondary routes highlight their owner', () {
      expect(aikoSelectedPath('/transaction-rules', bar), '/transactions');
      expect(aikoSelectedPath('/travel-mode', bar), '/transactions');
      expect(aikoSelectedPath('/account-form', bar), '/accounts');
      expect(aikoSelectedPath('/profile', bar), '/aiko');
      expect(aikoSelectedPath('/connect-line', bar), '/aiko');
    });

    test('an owner that is itself an entry wins over its parent', () {
      expect(
        aikoSelectedPath('/connect-line', [...bar, '/profile']),
        '/profile',
      );
    });

    test('prefers the longest matching entry', () {
      final entries = ['/settings', '/settings/chance-of-success'];
      expect(
        aikoSelectedPath('/settings/chance-of-success', entries),
        '/settings/chance-of-success',
      );
      expect(aikoSelectedPath('/settings', entries), '/settings');
    });

    test('falls back to Overview', () {
      expect(aikoSelectedPath('/calculators', bar), '/home');
      expect(aikoSelectedPath('/notifications', bar), '/home');
    });
  });

  group('aikoNavigationTarget', () {
    final now = DateTime.fromMicrosecondsSinceEpoch(42);

    test('re-tapping Transactions resets its filters', () {
      expect(
        aikoNavigationTarget('/transactions', reselected: true, now: now),
        '/transactions?reset=42',
      );
    });

    test('other taps navigate to the path', () {
      expect(
        aikoNavigationTarget('/transactions', reselected: false, now: now),
        '/transactions',
      );
      expect(aikoNavigationTarget('/home', reselected: true), '/home');
    });
  });
}
