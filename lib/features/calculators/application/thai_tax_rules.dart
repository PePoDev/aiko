import 'dart:math' as math;

/// Thai personal income tax (Revenue Code section 48), as in force since tax
/// year 2017. Amounts are baht per tax year. Estimates only: the calculators
/// apply the common deductions, not every allowance a taxpayer may claim.
abstract final class ThaiIncomeTax {
  /// Upper bound of each bracket and its rate, lowest first.
  static const brackets = <({double upTo, double rate})>[
    (upTo: 150000, rate: 0),
    (upTo: 300000, rate: 0.05),
    (upTo: 500000, rate: 0.10),
    (upTo: 750000, rate: 0.15),
    (upTo: 1000000, rate: 0.20),
    (upTo: 2000000, rate: 0.25),
    (upTo: 5000000, rate: 0.30),
    (upTo: double.infinity, rate: 0.35),
  ];

  /// Personal allowance every taxpayer may deduct.
  static const personalAllowance = 60000.0;

  /// Employment income (salary, bonus) may deduct 50% as expenses, up to
  /// 100,000 baht.
  static double employmentExpenseDeduction(double employmentIncome) =>
      math.min(math.max(employmentIncome, 0) * 0.5, 100000);

  /// Progressive tax on [netIncome] (income after expenses and allowances).
  static double taxOn(double netIncome) {
    var tax = 0.0;
    var lower = 0.0;
    for (final bracket in brackets) {
      if (netIncome <= lower) break;
      final taxed = math.min(netIncome, bracket.upTo) - lower;
      tax += taxed * bracket.rate;
      lower = bracket.upTo;
    }
    return tax;
  }

  /// The rate applied to the next baht of [netIncome].
  static double marginalRate(double netIncome) {
    for (final bracket in brackets) {
      if (netIncome < bracket.upTo) return bracket.rate;
    }
    return brackets.last.rate;
  }

  /// Net taxable income from a year of employment income after the expense
  /// deduction, the personal allowance and [otherDeductions] (social
  /// security, insurance, funds…). Never negative.
  static double netEmploymentIncome(
    double employmentIncome, {
    double otherDeductions = 0,
  }) {
    final net =
        employmentIncome -
        employmentExpenseDeduction(employmentIncome) -
        personalAllowance -
        otherDeductions;
    return math.max(net, 0);
  }

  /// Tax-deductible purchase limit for a year: RMF allows 30% of income up
  /// to 500,000 baht (shared with other retirement savings); Thai ESG allows
  /// 30% of income up to 300,000 baht under the scheme for purchases through
  /// 2026, which is due to revert to stricter terms from 2027.
  static double fundDeductionCap({
    required double annualIncome,
    required bool thaiEsg,
  }) => math.min(annualIncome * 0.30, thaiEsg ? 300000 : 500000);
}

/// Thai Social Security Fund, Section 33 (employees): old-age benefit.
abstract final class ThaiSocialSecurity {
  /// Contributions count wages up to this monthly ceiling: 17,500 baht from
  /// 2026 (15,000 before), rising in later phases. Editable in the
  /// calculator because the Social Security Office revises it.
  static const defaultWageCeiling = 17500.0;

  /// Months of contributions needed for a monthly pension.
  static const pensionMonths = 180;

  /// Old-age benefit at 55 after leaving insured employment: a monthly
  /// pension of 20% of the average capped wage of the last 60 months, plus
  /// 1.5% for each full 12 months beyond 180, when at least 180 months were
  /// paid; otherwise a lump sum of the old-age contributions (the worker's
  /// 3% share, plus the employer's 3% from 12 months on), before the returns
  /// the fund adds.
  static ({double? monthlyPension, double? lumpSum, double rate})
  oldAgeBenefit({
    required double averageMonthlyWage,
    required int monthsContributed,
    double wageCeiling = defaultWageCeiling,
  }) {
    final wage = math.min(averageMonthlyWage, wageCeiling);
    if (monthsContributed >= pensionMonths) {
      final extraYears = (monthsContributed - pensionMonths) ~/ 12;
      final rate = 0.20 + 0.015 * extraYears;
      return (monthlyPension: wage * rate, lumpSum: null, rate: rate);
    }
    final share = monthsContributed < 12 ? 0.03 : 0.06;
    return (
      monthlyPension: null,
      lumpSum: wage * share * monthsContributed,
      rate: share,
    );
  }
}
