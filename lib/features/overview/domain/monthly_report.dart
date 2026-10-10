import '../../../core/money/money.dart';

/// One category's share of this month's spending, for the report donut + list.
class MonthlyReportSlice {
  const MonthlyReportSlice({
    required this.name,
    required this.colorHex,
    required this.amount,
  });

  final String name;
  final String colorHex;
  final Money amount;
}

/// Real monthly figures derived from the user's transactions. Computed by
/// [MonthlyReportService]; never mock data. All money is in the report's base
/// currency. Change percentages are null when the prior month has no data to
/// compare against (so the UI hides the change chip instead of showing 0%).
class MonthlyReport {
  const MonthlyReport({
    required this.income,
    required this.expenses,
    required this.netCashFlow,
    required this.saved,
    required this.savingsRatePct,
    required this.incomeChangePct,
    required this.expensesChangePct,
    required this.netChangePct,
    required this.savedVsLastMonth,
    required this.slices,
  });

  final Money income;
  final Money expenses;
  final Money netCashFlow;

  /// Net cash flow floored at zero — money actually kept this month.
  final Money saved;

  /// `saved / income * 100`; 0 when there is no income.
  final double savingsRatePct;

  final double? incomeChangePct;
  final double? expensesChangePct;
  final double? netChangePct;

  /// `thisMonthNet - lastMonthNet`, for the headline notice.
  final Money savedVsLastMonth;

  /// Expense breakdown, largest first, capped to a handful of slices with the
  /// remainder folded into a final "Other" slice.
  final List<MonthlyReportSlice> slices;

  bool get hasActivity => !income.isZero || !expenses.isZero;
}

/// Whether a month-on-month change reads as good or bad news.
enum ChangeTone { good, bad, flat }

/// The tone of a change of [pct] percent: for metrics where
/// [higherIsBetter] (income, net cash flow) a rise is good; for spending a
/// fall is good.
ChangeTone changeTone(double pct, {required bool higherIsBetter}) {
  if (pct == 0) return ChangeTone.flat;
  return (pct > 0) == higherIsBetter ? ChangeTone.good : ChangeTone.bad;
}
