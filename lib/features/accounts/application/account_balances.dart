import '../../../core/money/money.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/account.dart';

/// Each account's current balance, keyed by account id, in one pass over
/// [transactions]: the sum of an account's transactions when it has any,
/// otherwise its stored [Account.currentBalance].
Map<String, Money> currentAccountBalances(
  List<Account> accounts,
  Iterable<FinanceTransaction> transactions,
) {
  final accountsById = {for (final account in accounts) account.id: account};
  final fromLedger = <String, Money>{};
  for (final transaction in transactions) {
    final account = accountsById[transaction.accountId];
    if (account == null) continue;
    fromLedger[account.id] = transaction.applyToAccountBalance(
      fromLedger[account.id] ?? Money.zero(account.currency),
    );
  }
  return {
    for (final account in accounts)
      account.id: fromLedger[account.id] ?? account.currentBalance,
  };
}

/// Whether [account] counts toward net worth, matching the Overview
/// (`buildDashboardSummary`): active, not a goal, and included by the user.
bool countsTowardNetWorth(Account account) =>
    account.isActive &&
    account.type != AccountType.goal &&
    account.includeInNetWorth;

/// Sum of [balances] for [accounts] held in [baseCurrency]. Accounts in other
/// currencies are skipped rather than converted, so units never mix. Null when
/// no account contributes.
Money? sumBalancesInCurrency({
  required Iterable<Account> accounts,
  required Map<String, Money> balances,
  required String baseCurrency,
}) {
  Money? total;
  final upper = baseCurrency.toUpperCase();
  for (final account in accounts) {
    if (account.currency.toUpperCase() != upper) continue;
    final balance = balances[account.id] ?? account.currentBalance;
    total = total == null ? balance : total + balance;
  }
  return total;
}

/// The Accounts screen's summary figures in [baseCurrency].
class AccountsSummary {
  const AccountsSummary({
    required this.total,
    required this.netWorth,
    required this.assets,
    required this.liabilities,
  });

  /// Every account's balance (base-currency accounts only).
  final Money? total;

  /// Accounts that [countsTowardNetWorth]; equals [assets] − [liabilities].
  final Money? netWorth;

  /// Positive balances of net-worth accounts.
  final Money? assets;

  /// What net-worth accounts owe (their negative balances, as a positive
  /// amount). Sign-based rather than type-based so a card in credit counts as
  /// an asset.
  final Money? liabilities;
}

AccountsSummary summarizeAccounts({
  required List<Account> accounts,
  required Map<String, Money> balances,
  required String baseCurrency,
}) {
  final netWorthAccounts = accounts.where(countsTowardNetWorth);
  Money? assets;
  Money? liabilities;
  final upper = baseCurrency.toUpperCase();
  for (final account in netWorthAccounts) {
    if (account.currency.toUpperCase() != upper) continue;
    final balance = balances[account.id] ?? account.currentBalance;
    if (balance.isNegative) {
      final owed = Money.zero(account.currency) - balance;
      liabilities = liabilities == null ? owed : liabilities + owed;
    } else {
      assets = assets == null ? balance : assets + balance;
    }
  }
  return AccountsSummary(
    total: sumBalancesInCurrency(
      accounts: accounts,
      balances: balances,
      baseCurrency: baseCurrency,
    ),
    netWorth: sumBalancesInCurrency(
      accounts: netWorthAccounts,
      balances: balances,
      baseCurrency: baseCurrency,
    ),
    assets: assets,
    liabilities: liabilities,
  );
}
