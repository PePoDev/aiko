import 'package:aiko/core/money/money.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/core/offline/offline_store.dart';
import 'package:aiko/features/accounts/data/account_repository.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/onboarding/application/complete_onboarding.dart';
import 'package:aiko/features/onboarding/application/default_accounts_seed_marker.dart';
import 'package:aiko/features/settings/data/profile_repository.dart';
import 'package:aiko/features/settings/domain/profile.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(this.userId);

  final String userId;

  @override
  Future<Profile> load() async => Profile(
    id: userId,
    displayName: 'Ann',
    email: '',
    baseCurrency: 'THB',
    country: 'TH',
    securityStatus: SecurityStatus.notConfigured,
  );
}

class _FakeAccountRepository extends AccountRepository {
  final accounts = <Account>[];

  @override
  Future<List<Account>> list() async => List.of(accounts);

  @override
  Future<Account> save(Account account, {RecordBatch? batch}) async {
    accounts.add(account);
    return account;
  }
}

void main() {
  final english = lookupAppLocalizations(const Locale('en'));

  test('the marker is per user', () async {
    final marker = DefaultAccountsSeedMarker(MemorySecureStorageService());

    expect(await marker.isSeeded('local:a'), isFalse);
    await marker.markSeeded('local:a');
    expect(await marker.isSeeded('local:a'), isTrue);
    expect(await marker.isSeeded('local:b'), isFalse);
  });

  test(
    'seeds Cash and Bank once, then leaves deleted defaults deleted',
    () async {
      final storage = MemorySecureStorageService();
      final accounts = _FakeAccountRepository();
      final profiles = _FakeProfileRepository('local:a');

      await completeOnboarding(
        accountRepository: accounts,
        profileRepository: profiles,
        l10n: english,
        storage: storage,
      );
      expect(accounts.accounts.map((a) => a.type), [
        AccountType.cash,
        AccountType.bank,
      ]);
      expect(accounts.accounts.first.currentBalance, Money.zero('THB'));

      // The user deletes both defaults; the next launch must not restore them.
      accounts.accounts.clear();
      await completeOnboarding(
        accountRepository: accounts,
        profileRepository: profiles,
        l10n: english,
        storage: storage,
      );
      expect(accounts.accounts, isEmpty);
    },
  );

  test('another user on the device still gets defaults', () async {
    final storage = MemorySecureStorageService();
    await DefaultAccountsSeedMarker(storage).markSeeded('local:a');
    final accounts = _FakeAccountRepository();

    await completeOnboarding(
      accountRepository: accounts,
      profileRepository: _FakeProfileRepository('uid-b'),
      l10n: english,
      storage: storage,
    );

    expect(accounts.accounts, hasLength(2));
  });
}
