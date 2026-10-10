import 'package:aiko/features/calculators/application/calculator_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('biweekly payments finish a mortgage sooner with less interest', () {
    final plan = CalculatorServices.biweeklyMortgage(
      principal: 1000000,
      annualRate: 0.06,
      years: 30,
    );
    expect(plan.biweeklyPayment, closeTo(plan.monthlyPayment / 2, 1e-9));
    expect(plan.biweeklyYears, lessThan(30));
    expect(plan.biweeklyYears, greaterThan(20));
    expect(plan.biweeklyTotalInterest, lessThan(plan.monthlyTotalInterest));
  });

  test('refinance savings and break-even month', () {
    final refinance = CalculatorServices.refinance(
      balance: 1000000,
      currentRate: 0.07,
      remainingMonths: 240,
      newRate: 0.05,
      newMonths: 240,
      closingCosts: 20000,
    );
    expect(refinance.currentPayment, closeTo(7752.99, 0.01));
    expect(refinance.newPayment, closeTo(6599.56, 0.01));
    expect(refinance.breakEvenMonths, 18);
    expect(refinance.totalSavings, closeTo(256823.67, 0.01));

    final worse = CalculatorServices.refinance(
      balance: 1000000,
      currentRate: 0.05,
      remainingMonths: 240,
      newRate: 0.07,
      newMonths: 240,
    );
    expect(worse.breakEvenMonths, isNull);
    expect(worse.totalSavings, lessThan(0));
  });

  test('rent versus buy compares net costs', () {
    final cash = CalculatorServices.rentVsBuy(
      homePrice: 1000000,
      downPaymentRate: 1,
      loanRate: 0,
      loanYears: 30,
      monthlyRent: 5000,
      years: 10,
      homeGrowthRate: 0,
      rentGrowthRate: 0,
      ownershipCostRate: 0.01,
      investmentReturn: 0,
    );
    expect(cash.buyCost, closeTo(100000, 1e-6));
    expect(cash.rentCost, closeTo(600000, 1e-6));
    expect(cash.homeEquity, closeTo(1000000, 1e-6));

    final financed = CalculatorServices.rentVsBuy(
      homePrice: 3000000,
      downPaymentRate: 0.1,
      loanRate: 0.06,
      loanYears: 30,
      monthlyRent: 12000,
      years: 5,
    );
    expect(financed.homeEquity, greaterThan(300000));
    expect(
      () => CalculatorServices.rentVsBuy(
        homePrice: 1000000,
        downPaymentRate: 0.1,
        loanRate: 0.06,
        loanYears: 30,
        monthlyRent: 5000,
        years: 0,
      ),
      throwsArgumentError,
    );
  });

  test('home affordability from the debt-to-income ratio', () {
    final affordable = CalculatorServices.homeAffordability(
      monthlyIncome: 50000,
      monthlyDebts: 5000,
      debtRatio: 0.4,
      annualRate: 0,
      months: 360,
      downPayment: 100000,
    );
    expect(affordable.maxPayment, 15000);
    expect(affordable.maxLoan, 5400000);
    expect(affordable.maxPrice, 5500000);

    final overextended = CalculatorServices.homeAffordability(
      monthlyIncome: 20000,
      monthlyDebts: 9000,
      debtRatio: 0.4,
      annualRate: 0.06,
      months: 360,
    );
    expect(overextended.maxPayment, lessThan(0));
    expect(overextended.maxLoan, 0);
  });

  test('rental cash flow, cap rate and gross yield', () {
    final rental = CalculatorServices.rentalCashFlow(
      price: 2000000,
      monthlyRent: 12000,
      vacancyRate: 0.05,
      monthlyCosts: 1000,
      monthlyLoanPayment: 5000,
    );
    expect(rental.monthlyCashFlow, closeTo(5400, 1e-9));
    expect(rental.annualNetOperatingIncome, closeTo(124800, 1e-9));
    expect(rental.capRate, closeTo(0.0624, 1e-12));
    expect(rental.grossYield, closeTo(0.072, 1e-12));
    expect(
      () => CalculatorServices.rentalCashFlow(price: 0, monthlyRent: 1000),
      throwsArgumentError,
    );
  });

  test('hire purchase uses a flat rate; lease is the sum of payments', () {
    final car = CalculatorServices.hirePurchaseVsLease(
      price: 800000,
      downPayment: 200000,
      flatRate: 0.03,
      months: 48,
      leasePayment: 15000,
      resaleValue: 400000,
    );
    expect(car.totalInterest, closeTo(72000, 1e-9));
    expect(car.installment, closeTo(14000, 1e-9));
    expect(car.buyCost, closeTo(472000, 1e-9));
    expect(car.leaseCost, 720000);
    // The flat rate understates the true (declining-balance) rate.
    expect(car.effectiveRate, greaterThan(0.05));
    expect(
      CalculatorServices.loanPayment(
        principal: 600000,
        annualRate: car.effectiveRate,
        months: 48,
      ),
      closeTo(14000, 1e-6),
    );
  });
}
