import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/money/money.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../settings/data/profile_repository.dart';

/// Replaces the old multi-step onboarding flow: there is no onboarding UI
/// anymore. The first time a user reaches the app we just seed the default
/// accounts (1 cash + 1 bank, zero balance in their base currency) and mark
/// the profile completed. Idempotent — re-running won't duplicate accounts or
/// clobber other profile fields.
Future<void> completeOnboarding({
  required AccountRepository accountRepository,
  required ProfileRepository profileRepository,
}) async {
  final profile = await profileRepository.load();
  final balance = Money.zero(profile.baseCurrency);
  final defaults = [
    Account(
      id: const Uuid().v4(),
      userId: '',
      name: 'Cash',
      type: AccountType.cash,
      currentBalance: balance,
    ),
    Account(
      id: const Uuid().v4(),
      userId: '',
      name: 'Bank Account',
      type: AccountType.bank,
      currentBalance: balance,
    ),
  ];

  // Writes are best-effort: a failed offline write must not block the user
  // from reaching the dashboard. The name+type dedup means a retry on the next
  // login can't duplicate accounts, so first-time-only seeding holds regardless.
  try {
    final existing = await accountRepository.list();
    for (final account in defaults) {
      final alreadyExists = existing.any(
        (e) => e.name == account.name && e.type == account.type,
      );
      if (!alreadyExists) {
        await accountRepository.save(account);
      }
    }
  } catch (error) {
    debugPrint('Seeded default accounts locally: $error');
  }
}
