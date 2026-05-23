import 'package:aiko/app/providers.dart';
import 'package:aiko/features/settings/data/profile_repository.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:aiko/features/settings/presentation/profile_screen.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('profile email field is read-only', (tester) async {
    final repository = _FakeProfileRepository(_profile);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const ProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final emailField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.controller?.text == 'person@example.com',
    );

    expect(emailField, findsOneWidget);
    expect(tester.widget<TextField>(emailField).readOnly, isTrue);
  });

  testWidgets('saving profile preserves account email', (tester) async {
    final repository = _FakeProfileRepository(_profile);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const ProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.controller?.text == 'Person Name',
      ),
      'Updated Name',
    );
    final saveButton = find.text('Save changes');
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.savedProfile?.displayName, 'Updated Name');
    expect(repository.savedProfile?.email, 'person@example.com');
  });

  testWidgets('profile screen does not show appearance settings', (
    tester,
  ) async {
    final repository = _FakeProfileRepository(_profile);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AikoTheme.light(),
          home: const ProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsNothing);
    expect(find.text('System default'), findsNothing);
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
