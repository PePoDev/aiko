import 'package:aiko/features/calculators/application/calculator_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WACC weights after-tax debt and equity', () {
    expect(
      CalculatorServices.wacc(
        equityValue: 600,
        debtValue: 400,
        costOfEquity: 0.10,
        costOfDebt: 0.05,
        taxRate: 0.2,
      ),
      closeTo(0.076, 1e-12),
    );
    expect(
      () => CalculatorServices.wacc(
        equityValue: 0,
        debtValue: 0,
        costOfEquity: 0.1,
        costOfDebt: 0.05,
        taxRate: 0.2,
      ),
      throwsArgumentError,
    );
  });

  test('CAPM adds beta times the market premium', () {
    expect(
      CalculatorServices.capm(
        riskFreeRate: 0.02,
        beta: 1.2,
        marketReturn: 0.08,
      ),
      closeTo(0.092, 1e-12),
    );
  });

  test('Black–Scholes matches textbook prices and put–call parity', () {
    expect(CalculatorServices.normalCdf(0), closeTo(0.5, 1e-9));
    expect(CalculatorServices.normalCdf(1.96), closeTo(0.975, 1e-4));
    expect(CalculatorServices.normalCdf(-1.96), closeTo(0.025, 1e-4));

    final option = CalculatorServices.blackScholes(
      spot: 100,
      strike: 100,
      years: 1,
      volatility: 0.2,
      riskFreeRate: 0.05,
    );
    expect(option.call, closeTo(10.4506, 1e-3));
    expect(option.put, closeTo(5.5735, 1e-3));
    expect(
      () => CalculatorServices.blackScholes(
        spot: 100,
        strike: 100,
        years: 0,
        volatility: 0.2,
        riskFreeRate: 0.05,
      ),
      throwsArgumentError,
    );
  });

  test('retirement drawdown counts the months savings last', () {
    final exact = CalculatorServices.retirementDrawdown(
      savings: 120000,
      monthlyWithdrawal: 10000,
    );
    expect(exact.months, 12);
    expect(exact.totalWithdrawn, 120000);
    expect(exact.lastsForever, isFalse);

    final partial = CalculatorServices.retirementDrawdown(
      savings: 125000,
      monthlyWithdrawal: 10000,
    );
    expect(partial.months, closeTo(12.5, 1e-9));

    final inflating = CalculatorServices.retirementDrawdown(
      savings: 240000,
      monthlyWithdrawal: 10000,
      annualInflation: 0.5,
    );
    // 12 × 10,000 in year one, then 15,000 a month: 8 more months.
    expect(inflating.months, closeTo(20, 1e-9));

    final forever = CalculatorServices.retirementDrawdown(
      savings: 1000000,
      monthlyWithdrawal: 1000,
      annualReturn: 0.05,
    );
    expect(forever.lastsForever, isTrue);
    expect(
      () => CalculatorServices.retirementDrawdown(
        savings: 1000,
        monthlyWithdrawal: 0,
      ),
      throwsArgumentError,
    );
  });
}
