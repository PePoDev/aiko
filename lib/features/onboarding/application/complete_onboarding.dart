import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/money/money.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../settings/data/profile_repository.dart';

/// Replaces the old multi-step onboarding flow: there is no onboarding UI
/// anymore. The first time a user reaches the app we just seed the default
/// accounts (1 cash + 1 bank, zero balance in their base currency) and mark
/// the profile completed. Idempotent — re-running won't duplicate accounts or
/// clobber other profile fields. Account names use the current language
/// ([l10n], default [currentL10n]).
Future<void> completeOnboarding({
  required AccountRepository accountRepository,
  required ProfileRepository profileRepository,
  AppLocalizations? l10n,
}) async {
  final strings = l10n ?? currentL10n();
  final profile = await profileRepository.load();
  final balance = Money.zero(profile.baseCurrency);
  final defaults = [
    Account(
      id: const Uuid().v4(),
      userId: '',
      name: strings.defaultCashAccountName,
      type: AccountType.cash,
      currentBalance: balance,
    ),
    Account(
      id: const Uuid().v4(),
      userId: '',
      name: strings.defaultBankAccountName,
      type: AccountType.bank,
      currentBalance: balance,
    ),
  ];

  // Writes are best-effort: a failed offline write must not block the user
  // from reaching the dashboard. The name+type dedup means a retry on the next
  // login can't duplicate accounts, so first-time-only seeding holds regardless.
  // Names are compared in every language, so switching language between runs
  // doesn't duplicate them either.
  final everyLanguage = AppLocalizations.supportedLocales.map(
    lookupAppLocalizations,
  );
  final defaultNames = {
    AccountType.cash: {
      for (final l10n in everyLanguage) l10n.defaultCashAccountName,
    },
    AccountType.bank: {
      for (final l10n in everyLanguage) l10n.defaultBankAccountName,
    },
  };
  try {
    final existing = await accountRepository.list();
    for (final account in defaults) {
      final alreadyExists = existing.any(
        (e) =>
            e.type == account.type &&
            (defaultNames[account.type] ?? {account.name}).contains(e.name),
      );
      if (!alreadyExists) {
        await accountRepository.save(account);
      }
    }
  } catch (error) {
    debugPrint('Seeded default accounts locally: $error');
  }
}
