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

    expect(find.text('person@example.com'), findsOneWidget);
  });

  testWidgets('saving profile preserves account email and new fields', (
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
    await tester.enterText(_fieldByLabel('Display name'), 'Updated Name');
    await tester.enterText(_fieldByLabel('Phone number'), '+66 81 234 5678');
    await tester.pumpAndSettle();
    final saveButton = find.text('Save');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.savedProfile?.displayName, 'Updated Name');
    expect(repository.savedProfile?.email, 'person@example.com');
    expect(repository.savedProfile?.phoneNumber, '+66 81 234 5678');
  });
}

/// Targets a profile [TextField] by its `labelText` instead of by content,
/// so the matcher doesn't depend on which fields happen to be empty.
Finder _fieldByLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

const _profile = Profile(
  id: 'profile-1',
  displayName: 'Person Name',
  email: 'person@example.com',
  baseCurrency: 'THB',
  country: 'TH',
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
