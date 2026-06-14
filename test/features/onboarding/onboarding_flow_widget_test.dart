import 'package:aiko/app/providers.dart';
import 'package:aiko/features/accounts/data/account_repository.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/onboarding/presentation/onboarding_screens.dart';
import 'package:aiko/features/settings/data/profile_repository.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  testWidgets('onboarding flow goes from goal to first account and finishes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(_FakeAccountRepository()),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
        child: MaterialApp.router(
          theme: AikoTheme.light(),
          routerConfig: GoRouter(
            initialLocation: '/onboarding',
            routes: [
              GoRoute(
                path: '/onboarding',
                builder: (context, state) => const OnboardingFlowScreen(),
              ),
              GoRoute(
                path: '/home',
                builder: (context, state) =>
                    const Scaffold(body: Text('Aiko Home')),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.textContaining("What's your", skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Save More', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("Let's add your", skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Bank Account', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(find.text('Aiko Home', skipOffstage: false), findsOneWidget);
  });

  testWidgets('finishing onboarding twice does not duplicate first account', (
    tester,
  ) async {
    final accountRepository = _FakeAccountRepository();
    final profileRepository = _FakeProfileRepository();

    await _completeOnboarding(
      tester,
      accountRepository: accountRepository,
      profileRepository: profileRepository,
    );
    await _completeOnboarding(
      tester,
      accountRepository: accountRepository,
      profileRepository: profileRepository,
    );

    final chaseAccounts = accountRepository.accounts.where(
      (account) => account.name == 'Chase Checking',
    );

    expect(chaseAccounts, hasLength(1));
  });
}

Future<void> _completeOnboarding(
  WidgetTester tester, {
  required _FakeAccountRepository accountRepository,
  required _FakeProfileRepository profileRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountRepositoryProvider.overrideWithValue(accountRepository),
        profileRepositoryProvider.overrideWithValue(profileRepository),
      ],
      child: MaterialApp.router(
        theme: AikoTheme.light(),
        routerConfig: GoRouter(
          initialLocation: '/onboarding',
          routes: [
            GoRoute(
              path: '/onboarding',
              builder: (context, state) => const OnboardingFlowScreen(),
            ),
            GoRoute(
              path: '/home',
              builder: (context, state) =>
                  const Scaffold(body: Text('Aiko Home')),
            ),
          ],
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Finish'));
  await tester.pumpAndSettle();
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
