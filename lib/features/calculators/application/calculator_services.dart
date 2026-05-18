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
}
