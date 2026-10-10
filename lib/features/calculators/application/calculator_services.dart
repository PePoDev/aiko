import 'dart:math' as math;

import 'thai_tax_rules.dart';

abstract final class CalculatorServices {
  static double compoundInterest({
    required double principal,
    required double monthlyContribution,
    required double annualRate,
    required int years,
  }) {
    final months = years * 12;
    final monthlyRate = annualRate / 12;
    var value = principal;
    for (var index = 0; index < months; index++) {
      value = (value + monthlyContribution) * (1 + monthlyRate);
    }
    return value;
  }

  static double loanPayment({
    required double principal,
    required double annualRate,
    required int months,
  }) {
    if (months <= 0) {
      throw ArgumentError('Term must be positive.');
    }
    final monthlyRate = annualRate / 12;
    if (monthlyRate == 0) {
      return principal / months;
    }
    return principal *
        (monthlyRate * math.pow(1 + monthlyRate, months)) /
        (math.pow(1 + monthlyRate, months) - 1);
  }

  static double roi({
    required double initialInvestment,
    required double endingValue,
    double fees = 0,
    double income = 0,
  }) {
    if (initialInvestment <= 0) {
      throw ArgumentError('Initial investment must be positive.');
    }
    return (endingValue + income - fees - initialInvestment) /
        initialInvestment;
  }

  static double convertCurrency({
    required double sourceAmount,
    required double exchangeRate,
  }) {
    if (exchangeRate <= 0) {
      throw ArgumentError('Exchange rate must be positive.');
    }
    return sourceAmount * exchangeRate;
  }

  static double ruleOf72({required double annualRate}) {
    if (annualRate <= 0) {
      throw ArgumentError('Annual rate must be positive.');
    }
    return 72 / (annualRate * 100);
  }

  static double netPresentValue({
    required double discountRate,
    required List<double> cashFlows,
  }) {
    return cashFlows.asMap().entries.fold<double>(0, (total, entry) {
      return total + entry.value / math.pow(1 + discountRate, entry.key);
    });
  }

  /// The discount rate at which [netPresentValue] is zero, or null when the
  /// cash flows don't change sign or no rate between −99% and 1,000% fits.
  static double? internalRateOfReturn(List<double> cashFlows) {
    final hasOutflow = cashFlows.any((flow) => flow < 0);
    final hasInflow = cashFlows.any((flow) => flow > 0);
    if (!hasOutflow || !hasInflow) return null;
    double npvAt(double rate) =>
        netPresentValue(discountRate: rate, cashFlows: cashFlows);
    var low = -0.99;
    var high = 10.0;
    final lowSign = npvAt(low).sign;
    if (lowSign == npvAt(high).sign) return null;
    for (var i = 0; i < 200; i++) {
      final mid = (low + high) / 2;
      if (npvAt(mid).sign == lowSign) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  static double taxEquivalentYield({
    required double taxFreeYield,
    required double marginalTaxRate,
  }) {
    if (marginalTaxRate >= 1) {
      throw ArgumentError('Marginal tax rate must be below 100%.');
    }
    return taxFreeYield / (1 - marginalTaxRate);
  }

  static double salaryToHourly({
    required double annualSalary,
    double hoursPerWeek = 40,
    double weeksPerYear = 52,
  }) {
    return annualSalary / (hoursPerWeek * weeksPerYear);
  }

  static double inflationAdjustedValue({
    required double amount,
    required double annualInflationRate,
    required int years,
  }) {
    return amount / math.pow(1 + annualInflationRate, years);
  }

  static double tipAmount({required double bill, required double tipRate}) {
    return bill * tipRate;
  }

  // ---- Time value of money ----

  /// What [futureValue] in [years] is worth today at [annualRate], compounded
  /// [periodsPerYear] times a year.
  static double presentValue({
    required double futureValue,
    required double annualRate,
    required int years,
    int periodsPerYear = 12,
  }) {
    final rate = annualRate / periodsPerYear;
    return futureValue / math.pow(1 + rate, years * periodsPerYear);
  }

  /// The saving per period that grows to [futureValue] in [years].
  static double sinkingFundPayment({
    required double futureValue,
    required double annualRate,
    required int years,
    int periodsPerYear = 12,
  }) {
    final periods = years * periodsPerYear;
    if (periods <= 0) throw ArgumentError('Term must be positive.');
    final rate = annualRate / periodsPerYear;
    if (rate == 0) return futureValue / periods;
    return futureValue * rate / (math.pow(1 + rate, periods) - 1);
  }

  /// Level payment per period that pays out [presentValue] over [years]
  /// while the balance keeps earning [annualRate].
  static double annuityPayment({
    required double presentValue,
    required double annualRate,
    required int years,
    int periodsPerYear = 12,
  }) {
    final periods = years * periodsPerYear;
    if (periods <= 0) throw ArgumentError('Term must be positive.');
    final rate = annualRate / periodsPerYear;
    if (rate == 0) return presentValue / periods;
    return presentValue * rate / (1 - math.pow(1 + rate, -periods));
  }

  /// Present value of [payment] made every period for [periods] periods.
  static double annuityPresentValue({
    required double payment,
    required double annualRate,
    required int periods,
    int periodsPerYear = 12,
  }) {
    final rate = annualRate / periodsPerYear;
    if (rate == 0) return payment * periods;
    return payment * (1 - math.pow(1 + rate, -periods)) / rate;
  }

  // ---- Deposits and bonds ----

  /// A fixed deposit paying simple interest at maturity, as Thai banks do,
  /// with [withholdingRate] tax taken from the interest (15% in Thailand).
  static ({
    double grossInterest,
    double tax,
    double maturityValue,
    double afterTaxYield,
  })
  fixedDeposit({
    required double principal,
    required double annualRate,
    required int months,
    double withholdingRate = 0.15,
  }) {
    if (months <= 0) throw ArgumentError('Term must be positive.');
    final interest = principal * annualRate * months / 12;
    final tax = interest * withholdingRate;
    return (
      grossInterest: interest,
      tax: tax,
      maturityValue: principal + interest - tax,
      afterTaxYield: (interest - tax) / principal * 12 / months,
    );
  }

  /// Bond price at an annual [yield], with coupons [periodsPerYear] times a
  /// year.
  static double bondPrice({
    required double faceValue,
    required double couponRate,
    required double yield,
    required double years,
    int periodsPerYear = 2,
  }) {
    final periods = (years * periodsPerYear).round();
    final coupon = faceValue * couponRate / periodsPerYear;
    final rate = yield / periodsPerYear;
    var price = 0.0;
    for (var k = 1; k <= periods; k++) {
      price += coupon / math.pow(1 + rate, k);
    }
    return price + faceValue / math.pow(1 + rate, periods);
  }

  /// Annual yield to maturity: the yield at which [bondPrice] equals [price].
  static double bondYieldToMaturity({
    required double faceValue,
    required double couponRate,
    required double price,
    required double years,
    int periodsPerYear = 2,
  }) {
    if ((years * periodsPerYear).round() <= 0) {
      throw ArgumentError('Term must be positive.');
    }
    double priceAt(double yield) => bondPrice(
      faceValue: faceValue,
      couponRate: couponRate,
      yield: yield,
      years: years,
      periodsPerYear: periodsPerYear,
    );
    var low = -0.5;
    var high = 2.0;
    if (price > priceAt(low) || price < priceAt(high)) {
      throw ArgumentError('Bond price is out of range.');
    }
    for (var i = 0; i < 200; i++) {
      final mid = (low + high) / 2;
      if (priceAt(mid) > price) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }

  // ---- Home and property ----

  /// Paying half the monthly payment every two weeks (26 half-payments a
  /// year, one extra monthly payment a year) on a [years]-year loan.
  static ({
    double monthlyPayment,
    double biweeklyPayment,
    double monthlyTotalInterest,
    double biweeklyTotalInterest,
    double biweeklyYears,
  })
  biweeklyMortgage({
    required double principal,
    required double annualRate,
    required int years,
  }) {
    final months = years * 12;
    final monthly = loanPayment(
      principal: principal,
      annualRate: annualRate,
      months: months,
    );
    final half = monthly / 2;
    final rate = annualRate / 26;
    var balance = principal;
    var interest = 0.0;
    var periods = 0;
    while (balance > 0.005 && periods < 26 * 100) {
      final periodInterest = balance * rate;
      interest += periodInterest;
      balance = balance + periodInterest - half;
      periods++;
    }
    return (
      monthlyPayment: monthly,
      biweeklyPayment: half,
      monthlyTotalInterest: monthly * months - principal,
      biweeklyTotalInterest: interest,
      biweeklyYears: periods / 26,
    );
  }

  /// Refinancing [balance] from the current loan to a new one.
  /// [breakEvenMonths] is null when the new payment isn't lower.
  static ({
    double currentPayment,
    double newPayment,
    double totalSavings,
    int? breakEvenMonths,
  })
  refinance({
    required double balance,
    required double currentRate,
    required int remainingMonths,
    required double newRate,
    required int newMonths,
    double closingCosts = 0,
  }) {
    final current = loanPayment(
      principal: balance,
      annualRate: currentRate,
      months: remainingMonths,
    );
    final next = loanPayment(
      principal: balance,
      annualRate: newRate,
      months: newMonths,
    );
    final monthlySaving = current - next;
    return (
      currentPayment: current,
      newPayment: next,
      totalSavings:
          current * remainingMonths - (next * newMonths + closingCosts),
      breakEvenMonths: monthlySaving > 0
          ? (closingCosts / monthlySaving).ceil()
          : null,
    );
  }

  /// Net cost of buying versus renting the same home for [years].
  ///
  /// Buying: down payment + loan payments + ownership costs (a share of the
  /// home's value each year) − the equity left at the end. Renting: rent
  /// (rising each year) − what the down payment would have earned invested.
  static ({double buyCost, double rentCost, double homeEquity}) rentVsBuy({
    required double homePrice,
    required double downPaymentRate,
    required double loanRate,
    required int loanYears,
    required double monthlyRent,
    required int years,
    double homeGrowthRate = 0.03,
    double rentGrowthRate = 0.03,
    double ownershipCostRate = 0.01,
    double investmentReturn = 0.04,
  }) {
    if (years <= 0) throw ArgumentError('Term must be positive.');
    final down = homePrice * downPaymentRate;
    final loan = homePrice - down;
    final loanMonths = loanYears * 12;
    final payment = loan > 0
        ? loanPayment(principal: loan, annualRate: loanRate, months: loanMonths)
        : 0.0;
    var balance = loan;
    var paid = 0.0;
    for (var month = 0; month < years * 12 && month < loanMonths; month++) {
      final interest = balance * loanRate / 12;
      balance = math.max(balance + interest - payment, 0);
      paid += payment;
    }
    var ownership = 0.0;
    var rent = 0.0;
    for (var year = 0; year < years; year++) {
      ownership +=
          homePrice * math.pow(1 + homeGrowthRate, year) * ownershipCostRate;
      rent += monthlyRent * 12 * math.pow(1 + rentGrowthRate, year);
    }
    final homeValue = homePrice * math.pow(1 + homeGrowthRate, years);
    final equity = homeValue - balance;
    final investmentGain = down * (math.pow(1 + investmentReturn, years) - 1);
    return (
      buyCost: down + paid + ownership - equity,
      rentCost: rent - investmentGain,
      homeEquity: equity,
    );
  }

  /// The most a buyer can borrow and spend when lenders cap all debt
  /// payments at [debtRatio] of income (Thai banks commonly use 40–50%).
  /// [maxPayment] is zero or negative when existing debts already use it up.
  static ({double maxPayment, double maxLoan, double maxPrice})
  homeAffordability({
    required double monthlyIncome,
    required double monthlyDebts,
    required double debtRatio,
    required double annualRate,
    required int months,
    double downPayment = 0,
  }) {
    if (months <= 0) throw ArgumentError('Term must be positive.');
    final maxPayment = monthlyIncome * debtRatio - monthlyDebts;
    final maxLoan = maxPayment > 0
        ? annuityPresentValue(
            payment: maxPayment,
            annualRate: annualRate,
            periods: months,
          )
        : 0.0;
    return (
      maxPayment: maxPayment,
      maxLoan: maxLoan,
      maxPrice: maxLoan + downPayment,
    );
  }

  /// Monthly cash flow and yields of a rental property.
  static ({
    double monthlyCashFlow,
    double annualNetOperatingIncome,
    double capRate,
    double grossYield,
  })
  rentalCashFlow({
    required double price,
    required double monthlyRent,
    double vacancyRate = 0,
    double monthlyCosts = 0,
    double monthlyLoanPayment = 0,
  }) {
    if (price <= 0) throw ArgumentError('Price must be positive.');
    final operatingIncome = monthlyRent * (1 - vacancyRate) - monthlyCosts;
    return (
      monthlyCashFlow: operatingIncome - monthlyLoanPayment,
      annualNetOperatingIncome: operatingIncome * 12,
      capRate: operatingIncome * 12 / price,
      grossYield: monthlyRent * 12 / price,
    );
  }

  // ---- Cars ----

  /// A Thai hire-purchase car loan (interest at a flat rate on the amount
  /// financed for the whole term) against leasing.
  /// [effectiveRate] is the equivalent declining-balance annual rate.
  static ({
    double installment,
    double totalInterest,
    double effectiveRate,
    double buyCost,
    double leaseCost,
  })
  hirePurchaseVsLease({
    required double price,
    required double downPayment,
    required double flatRate,
    required int months,
    required double leasePayment,
    double resaleValue = 0,
  }) {
    if (months <= 0) throw ArgumentError('Term must be positive.');
    final financed = math.max(price - downPayment, 0.0);
    final interest = financed * flatRate * months / 12;
    final installment = (financed + interest) / months;
    var effective = 0.0;
    if (financed > 0 && interest > 0) {
      var low = 0.0;
      var high = 2.0;
      for (var i = 0; i < 200; i++) {
        final mid = (low + high) / 2;
        final payment = loanPayment(
          principal: financed,
          annualRate: mid,
          months: months,
        );
        if (payment < installment) {
          low = mid;
        } else {
          high = mid;
        }
      }
      effective = (low + high) / 2;
    }
    return (
      installment: installment,
      totalInterest: interest,
      effectiveRate: effective,
      buyCost: downPayment + installment * months - resaleValue,
      leaseCost: leasePayment * months,
    );
  }

  // ---- Corporate finance and markets ----

  /// Weighted average cost of capital; debt is cheaper by the tax shield.
  static double wacc({
    required double equityValue,
    required double debtValue,
    required double costOfEquity,
    required double costOfDebt,
    required double taxRate,
  }) {
    final total = equityValue + debtValue;
    if (total <= 0) throw ArgumentError('Capital must be positive.');
    return equityValue / total * costOfEquity +
        debtValue / total * costOfDebt * (1 - taxRate);
  }

  /// Capital asset pricing model: expected return for an asset's [beta].
  static double capm({
    required double riskFreeRate,
    required double beta,
    required double marketReturn,
  }) => riskFreeRate + beta * (marketReturn - riskFreeRate);

  /// Black–Scholes prices of European call and put options.
  static ({double call, double put}) blackScholes({
    required double spot,
    required double strike,
    required double years,
    required double volatility,
    required double riskFreeRate,
    double dividendYield = 0,
  }) {
    if (spot <= 0 || strike <= 0 || years <= 0 || volatility <= 0) {
      throw ArgumentError('Option inputs must be positive.');
    }
    final sigmaRootT = volatility * math.sqrt(years);
    final d1 =
        (math.log(spot / strike) +
            (riskFreeRate - dividendYield + volatility * volatility / 2) *
                years) /
        sigmaRootT;
    final d2 = d1 - sigmaRootT;
    final discountedSpot = spot * math.exp(-dividendYield * years);
    final discountedStrike = strike * math.exp(-riskFreeRate * years);
    return (
      call: discountedSpot * normalCdf(d1) - discountedStrike * normalCdf(d2),
      put: discountedStrike * normalCdf(-d2) - discountedSpot * normalCdf(-d1),
    );
  }

  /// Standard normal cumulative distribution (Abramowitz–Stegun 7.1.26,
  /// accurate to about 1e-7).
  static double normalCdf(double x) {
    final z = x.abs() / math.sqrt2;
    final t = 1 / (1 + 0.3275911 * z);
    final poly =
        t *
        (0.254829592 +
            t *
                (-0.284496736 +
                    t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
    final erf = 1 - poly * math.exp(-z * z);
    return x >= 0 ? 0.5 * (1 + erf) : 0.5 * (1 - erf);
  }

  // ---- Retirement ----

  /// How long [savings] last when withdrawing [monthlyWithdrawal] (raised by
  /// [annualInflation] every year) while the balance earns [annualReturn].
  /// [months] is fractional for the last, partial withdrawal; [lastsForever]
  /// when the money outlasts 100 years.
  static ({double months, double totalWithdrawn, bool lastsForever})
  retirementDrawdown({
    required double savings,
    required double monthlyWithdrawal,
    double annualReturn = 0,
    double annualInflation = 0,
  }) {
    if (monthlyWithdrawal <= 0) {
      throw ArgumentError('Withdrawal must be positive.');
    }
    final monthlyReturn = math.pow(1 + annualReturn, 1 / 12) - 1;
    var balance = savings;
    var withdrawal = monthlyWithdrawal;
    var withdrawn = 0.0;
    for (var month = 0; month < 1200; month++) {
      if (month > 0 && month % 12 == 0) withdrawal *= 1 + annualInflation;
      if (balance < withdrawal) {
        withdrawn += balance;
        return (
          months: month + balance / withdrawal,
          totalWithdrawn: withdrawn,
          lastsForever: false,
        );
      }
      balance -= withdrawal;
      withdrawn += withdrawal;
      balance *= 1 + monthlyReturn;
    }
    return (months: 1200.0, totalWithdrawn: withdrawn, lastsForever: true);
  }

  // ---- Thai tax ----

  /// Monthly take-home pay after Thai personal income tax (spread over 12
  /// months, as employers withhold it) and the social security contribution.
  /// [otherDeductions] are yearly allowances besides the expense deduction,
  /// personal allowance and social security (insurance, funds, parents…).
  static ({
    double annualIncome,
    double netIncome,
    double annualTax,
    double monthlyTax,
    double takeHome,
    double effectiveRate,
    double marginalRate,
  })
  thaiTakeHomePay({
    required double monthlySalary,
    double annualBonus = 0,
    double monthlySocialSecurity = 0,
    double otherDeductions = 0,
  }) {
    final annualIncome = monthlySalary * 12 + annualBonus;
    final net = ThaiIncomeTax.netEmploymentIncome(
      annualIncome,
      otherDeductions: monthlySocialSecurity * 12 + otherDeductions,
    );
    final tax = ThaiIncomeTax.taxOn(net);
    return (
      annualIncome: annualIncome,
      netIncome: net,
      annualTax: tax,
      monthlyTax: tax / 12,
      takeHome: monthlySalary - tax / 12 - monthlySocialSecurity,
      effectiveRate: annualIncome > 0 ? tax / annualIncome : 0,
      marginalRate: ThaiIncomeTax.marginalRate(net),
    );
  }

  /// Thai tax on a gain from a sale. Gains on shares traded on the Stock
  /// Exchange of Thailand and on Thai mutual fund units are exempt for
  /// individuals; other gains (for example foreign shares, once brought into
  /// Thailand) are taxed as income on top of [otherNetIncome].
  static ({double gain, double tax, double afterTaxProfit})
  thaiCapitalGainsTax({
    required double proceeds,
    required double costBasis,
    double fees = 0,
    required bool exempt,
    double otherNetIncome = 0,
  }) {
    final gain = proceeds - costBasis - fees;
    final tax = exempt || gain <= 0
        ? 0.0
        : ThaiIncomeTax.taxOn(otherNetIncome + gain) -
              ThaiIncomeTax.taxOn(otherNetIncome);
    return (gain: gain, tax: tax, afterTaxProfit: gain - tax);
  }

  /// Buying a tax-saving fund (RMF or Thai ESG) every year: the tax saved,
  /// the fund's value, and the value of the tax refunds if reinvested at the
  /// same return.
  static ({
    double deductible,
    double annualTaxSaving,
    double fundValue,
    double refundsValue,
  })
  taxSavingFund({
    required double annualIncome,
    required double yearlyContribution,
    required int years,
    required double annualReturn,
    required bool thaiEsg,
    double otherDeductions = 0,
  }) {
    if (years <= 0) throw ArgumentError('Term must be positive.');
    final net = ThaiIncomeTax.netEmploymentIncome(
      annualIncome,
      otherDeductions: otherDeductions,
    );
    final deductible = math.min(
      yearlyContribution,
      ThaiIncomeTax.fundDeductionCap(
        annualIncome: annualIncome,
        thaiEsg: thaiEsg,
      ),
    );
    final saving =
        ThaiIncomeTax.taxOn(net) -
        ThaiIncomeTax.taxOn(math.max(net - deductible, 0));
    var fund = 0.0;
    var refunds = 0.0;
    for (var year = 0; year < years; year++) {
      fund = (fund + yearlyContribution) * (1 + annualReturn);
      refunds = refunds * (1 + annualReturn) + saving;
    }
    return (
      deductible: deductible,
      annualTaxSaving: saving,
      fundValue: fund,
      refundsValue: refunds,
    );
  }
}
