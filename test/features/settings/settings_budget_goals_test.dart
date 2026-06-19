import 'package:aiko/app/aiko_navigation.dart';
import 'package:aiko/app/providers.dart';
import 'package:aiko/features/settings/data/profile_repository.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:aiko/features/settings/presentation/settings_screen.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = Profile(
  id: 'user-1',
  displayName: 'Aiko',
  email: 'aiko@example.com',
  baseCurrency: 'USD',
  country: 'US',
  onboardingStatus: OnboardingStatus.completed,
  securityStatus: SecurityStatus.notConfigured,
  preferredTheme: PreferredTheme.system,
);

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this._profile);
  final Profile _profile;

  @override
  Future<Profile> load() async => _profile;

  @override
  Future<Profile> save(Profile profile) async => profile;
}

void main() {
  testWidgets(
    'settings lists every new budget/goal entry under one flat list',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(
              _FakeProfileRepository(_profile),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AikoTheme.light(),
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The six new budget/goal entries must all be visible.
      expect(find.text('Budget: Pace'), findsOneWidget);
      expect(find.text('Budget: Safe to Spend'), findsOneWidget);
      expect(find.text('Budget: Cash Flow'), findsOneWidget);
      expect(find.text('Budget: Cash Flow (Sankey)'), findsOneWidget);
      expect(find.text('Goals: Chance of Success'), findsOneWidget);

      // The list is a single flat container — no Planning/Insights/etc.
      // group headers.
      expect(find.text('Planning'), findsNothing);
      expect(find.text('Insights and AI'), findsNothing);
      expect(find.text('Tools and Data'), findsNothing);
      expect(find.text('Settings and Security'), findsNothing);

      // Every entry maps to a path.
      const expectedPaths = {
        '/settings/pace',
        '/settings/safe-to-spend',
        '/settings/cash-flow',
        '/settings/cash-flow-sankey',
        '/settings/chance-of-success',
      };
      final configuredPaths = aikoNavigationItems.map((e) => e.path).toSet();
      expect(configuredPaths.containsAll(expectedPaths), isTrue);
    },
  );
}
