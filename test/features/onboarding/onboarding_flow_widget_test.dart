import 'package:aiko/features/accounts/data/account_repository.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/onboarding/application/complete_onboarding.dart';
import 'package:aiko/features/settings/data/profile_repository.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('welcome screen introduces Aiko and leads to login', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.textContaining("Hi, I'm Aiko!"), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!', skipOffstage: false), findsOneWidget);
    expect(find.text('Log In', skipOffstage: false), findsOneWidget);
  });

  test('completeOnboarding seeds a cash + bank account and completes', () async {
    final accounts = _FakeAccountRepository();
    final profiles = _FakeProfileRepository();

    await completeOnboarding(
      accountRepository: accounts,
      profileRepository: profiles,
    );

    expect(accounts.accounts.map((a) => a.type).toSet(), {
      AccountType.cash,
      AccountType.bank,
    });
    expect(profiles.profile.onboardingStatus, OnboardingStatus.completed);
  });

  test('completeOnboarding is idempotent', () async {
    final accounts = _FakeAccountRepository();
    final profiles = _FakeProfileRepository();

    await completeOnboarding(
      accountRepository: accounts,
      profileRepository: profiles,
    );
    await completeOnboarding(
      accountRepository: accounts,
      profileRepository: profiles,
    );

    expect(accounts.accounts, hasLength(2));
  });
}

class _FakeAccountRepository extends AccountRepository {
  final accounts = <Account>[];

  @override
  Future<List<Account>> list() async {
    return List.unmodifiable(accounts);
  }

  @override
  Future<Account> save(Account account) async {
    accounts.add(account);
    return account;
  }
}

class _FakeProfileRepository extends ProfileRepository {
  var profile = const Profile(
    id: 'local:user',
    displayName: 'Aiko User',
    email: '',
    baseCurrency: 'THB',
    country: 'TH',
    onboardingStatus: OnboardingStatus.notStarted,
    securityStatus: SecurityStatus.notConfigured,
  );

  @override
  Future<Profile> load() async {
    return profile;
  }

  @override
  Future<Profile> save(Profile profile) async {
    this.profile = profile;
    return profile;
  }
}
