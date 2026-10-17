import 'package:decimal/decimal.dart';

import '../../../core/offline/offline_user_context.dart';
import '../../../core/offline/records/records.dart';
import '../../../l10n/app_localizations.dart';

/// The Cash and Bank accounts a guest was given on their first start
/// (`completeOnboarding`) and never used: still named as created (in any
/// language), zero balance, and no transaction on them. Signing in to an
/// existing account leaves these behind instead of adding a second Cash and
/// Bank account to it.
List<OfflineAccount> unusedGuestDefaultAccounts(
  List<OfflineAccount> accounts,
  List<OfflineTransaction> transactions,
) {
  final languages = AppLocalizations.supportedLocales.map(
    lookupAppLocalizations,
  );
  final defaultNames = <String, Set<String>>{
    'cash': {for (final l10n in languages) l10n.defaultCashAccountName},
    'bank': {for (final l10n in languages) l10n.defaultBankAccountName},
  };
  final used = {for (final transaction in transactions) transaction.accountId};
  return [
    for (final account in accounts)
      if (account.userId.startsWith(OfflineUserContext.localUserIdPrefix) &&
          (defaultNames[account.type]?.contains(account.name) ?? false) &&
          Decimal.tryParse(account.currentBalance) == Decimal.zero &&
          !used.contains(account.id))
        account,
  ];
}
