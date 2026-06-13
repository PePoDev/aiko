import 'package:aiko/app/locale_controller.dart';
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

void main() {
  testWidgets('settings exposes a language picker', (tester) async {
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

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Thai (ไทย)'), findsOneWidget);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsWidgets);
    expect(find.text('ไทย'), findsOneWidget);
  });

  testWidgets('selecting English updates the locale provider', (tester) async {
    late WidgetRef capturedRef;

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
          home: Consumer(
            builder: (context, ref, child) {
              capturedRef = ref;
              return const SettingsScreen();
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-option-en')));
    await tester.pumpAndSettle();

    final locale = capturedRef.read(appLocaleControllerProvider).asData?.value;
    expect(locale?.languageCode, 'en');
    expect(find.text('English (English)'), findsOneWidget);
  });

  testWidgets('settings exposes appearance outside profile', (tester) async {
    final repository = _FakeProfileRepository(_profile);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
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

    expect(find.text('App preferences'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance-option-dark')));
    await tester.pumpAndSettle();

    expect(repository.savedProfile?.preferredTheme, PreferredTheme.dark);
  });
}

const _profile = Profile(
  id: 'profile-1',
  displayName: 'Person Name',
  email: 'person@example.com',
  baseCurrency: 'THB',
  country: 'TH',
  aiConsentEnabled: false,
  onboardingStatus: OnboardingStatus.completed,
  securityStatus: SecurityStatus.notConfigured,
);

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(this._profile);

  Profile _profile;
  Profile? savedProfile;

  @override
  Future<Profile> load() async => _profile;

  @override
  Future<Profile> save(Profile profile) async {
    savedProfile = profile;
    _profile = profile;
    return profile;
  }
}
