import 'package:decimal/decimal.dart';

import '../../../core/money/exchange_rates.dart';
import '../../../core/money/money.dart';
import '../../accounts/domain/account.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/dashboard_summary.dart';

/// Converts amounts into [baseCurrency] with rates quoted against it
/// ([ratesFromBase]: how many units of each currency one base unit buys, as
/// `ExchangeRateService.fetchRates(base)` returns them).
class CurrencyConverter {
  CurrencyConverter(
    String baseCurrency, [
    Map<String, Decimal> ratesFromBase = const {},
  ]) : this._(baseCurrency, ratesFromBase, null);

  /// Converts with [rates]; [ratesAsOf] is set when they are the copy saved
  /// on the device, so totals can say how old they are.
  CurrencyConverter.from(ExchangeRates rates)
    : this._(rates.base, rates.rates, rates.savedAsOf);

  CurrencyConverter._(
    String baseCurrency,
    Map<String, Decimal> ratesFromBase,
    this.ratesAsOf,
  ) : baseCurrency = baseCurrency.toUpperCase(),
      _rates = {
        for (final entry in ratesFromBase.entries)
          entry.key.toUpperCase(): entry.value,
      };

  final String baseCurrency;
  final Map<String, Decimal> _rates;

  /// When the rates are the saved copy, the time they were fetched.
  final DateTime? ratesAsOf;

  /// [money] in the base currency, or null when there is no rate for it.
  Decimal? toBase(Money money) {
    final currency = money.currency.toUpperCase();
    if (currency == baseCurrency) return money.amount;
    final rate = _rates[currency];
    if (rate == null || rate <= Decimal.zero) return null;
    return (money.amount / rate).toDecimal(scaleOnInfinitePrecision: 10);
  }
}

/// The Overview's totals in the profile's base currency. Accounts and
/// transactions in other currencies are converted with [converter]; those it
/// has no rate for are left out and listed in
/// [DashboardSummary.excludedCurrencies] so the screen can say so.
DashboardSummary buildDashboardSummary({
  required List<Account> accounts,
  required List<FinanceTransaction> transactions,
  required CurrencyConverter converter,
  required DateTime now,
}) {
  final periodStart = DateTime(now.year, now.month);
  // Exclusive: the whole last day of the month counts.
  final nextMonthStart = DateTime(now.year, now.month + 1);
  final excluded = <String>{};
  var converted = false;
  Decimal inBase(Money money) {
    final amount = converter.toBase(money);
    if (amount == null) {
      excluded.add(money.currency.toUpperCase());
      return Decimal.zero;
    }
    if (money.currency.toUpperCase() != converter.baseCurrency) {
      converted = true;
    }
    return amount;
  }

  var netWorth = Decimal.zero;
  var totalCash = Decimal.zero;
  for (final account in accounts) {
    if (!account.isActive || account.type == AccountType.goal) continue;
    final amount = inBase(account.currentBalance);
    if (account.includeInNetWorth) {
      netWorth += amount;
    }
    if (account.type == AccountType.cash || account.type == AccountType.bank) {
      totalCash += amount;
    }
  }

  var monthlyIncome = Decimal.zero;
  var monthlySpending = Decimal.zero;
  var todaySpending = Decimal.zero;
  for (final transaction in transactions) {
    if (transaction.date.isBefore(periodStart) ||
        !transaction.date.isBefore(nextMonthStart)) {
      continue;
    }
    // Voided and archived transactions no longer count.
    if (transaction.status == TransactionStatus.voided ||
        transaction.status == TransactionStatus.archived) {
      continue;
    }
    if (transaction.isExpense &&
        transaction.status == TransactionStatus.posted &&
        transaction.date.day == now.day) {
      todaySpending += inBase(transaction.amount);
    }
    if (transaction.type == TransactionType.income) {
      monthlyIncome += inBase(transaction.amount);
    } else if (transaction.type == TransactionType.expense) {
      monthlySpending += inBase(transaction.amount);
    }
  }

  final weeklyFlow = ((monthlyIncome - monthlySpending) / Decimal.parse('4.33'))
      .toDecimal(scaleOnInfinitePrecision: 2);
  final safeToSpend = weeklyFlow > Decimal.zero ? weeklyFlow : Decimal.zero;
  Money money(Decimal amount) =>
      Money(amount: amount, currency: converter.baseCurrency);

  return DashboardSummary(
    netWorth: money(netWorth),
    totalCash: money(totalCash),
    monthlyIncome: money(monthlyIncome),
    monthlySpending: money(monthlySpending),
    safeToSpend: money(safeToSpend),
    todaySpending: money(todaySpending),
    excludedCurrencies: excluded,
    ratesAsOf: converted ? converter.ratesAsOf : null,
  );
}

/// Currencies other than [baseCurrency] that [buildDashboardSummary] would
/// need rates for at [now], so callers fetch rates only when there are any.
Set<String> foreignCurrencies({
  required String baseCurrency,
  required List<Account> accounts,
  required List<FinanceTransaction> transactions,
  required DateTime now,
}) {
  final base = baseCurrency.toUpperCase();
  final periodStart = DateTime(now.year, now.month);
  return {
    for (final account in accounts)
      if (account.isActive) account.currency.toUpperCase(),
    for (final transaction in transactions)
      if (!transaction.date.isBefore(periodStart))
        transaction.amount.currency.toUpperCase(),
  }..removeWhere((currency) => currency == base || currency.isEmpty);
}
