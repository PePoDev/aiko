import 'dart:math' as math;

class CalculatorServices {
  const CalculatorServices();

  double compoundInterest({
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

  double loanPayment({
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

  double roi({
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

  double convertCurrency({
    required double sourceAmount,
    required double exchangeRate,
  }) {
    if (exchangeRate <= 0) {
      throw ArgumentError('Exchange rate must be positive.');
    }
    return sourceAmount * exchangeRate;
  }

  double ruleOf72({required double annualRate}) {
    if (annualRate <= 0) {
      throw ArgumentError('Annual rate must be positive.');
    }
    return 72 / (annualRate * 100);
  }

  double netPresentValue({
    required double discountRate,
    required List<double> cashFlows,
  }) {
    return cashFlows.asMap().entries.fold<double>(0, (total, entry) {
      return total + entry.value / math.pow(1 + discountRate, entry.key);
    });
  }

  double taxEquivalentYield({
    required double taxFreeYield,
    required double marginalTaxRate,
  }) {
    if (marginalTaxRate >= 1) {
      throw ArgumentError('Marginal tax rate must be below 100%.');
    }
    return taxFreeYield / (1 - marginalTaxRate);
  }

  double salaryToHourly({
    required double annualSalary,
    double hoursPerWeek = 40,
    double weeksPerYear = 52,
  }) {
    return annualSalary / (hoursPerWeek * weeksPerYear);
  }

  double inflationAdjustedValue({
    required double amount,
    required double annualInflationRate,
    required int years,
  }) {
    return amount / math.pow(1 + annualInflationRate, years);
  }

  double tipAmount({required double bill, required double tipRate}) {
    return bill * tipRate;
  }
}
