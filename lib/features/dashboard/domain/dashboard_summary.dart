import '../../../core/money/money.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.netWorth,
    required this.totalCash,
    required this.monthlyIncome,
    required this.monthlySpending,
    required this.safeToSpend,
    required this.todaySpending,
    this.excludedCurrencies = const {},
    this.ratesAsOf,
  });

  final Money netWorth;
  final Money totalCash;
  final Money monthlyIncome;
  final Money monthlySpending;
  final Money safeToSpend;

  /// Posted expenses dated today.
  final Money todaySpending;

  /// Currencies left out of the totals because no exchange rate was
  /// available (for example offline).
  final Set<String> excludedCurrencies;

  /// When amounts in other currencies were converted with the exchange rates
  /// saved on the device (offline), the time those were fetched.
  final DateTime? ratesAsOf;
}
