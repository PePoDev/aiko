import 'package:aiko/features/calculators/application/calculator_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('present value discounts by the periodic rate', () {
    expect(
      CalculatorServices.presentValue(
        futureValue: 1000,
        annualRate: 0,
        years: 5,
      ),
      1000,
    );
    expect(
      CalculatorServices.presentValue(
        futureValue: 1000,
        annualRate: 0.12,
        years: 1,
      ),
      closeTo(887.449, 0.001),
    );
  });

  test('sinking fund and annuity payments', () {
    expect(
      CalculatorServices.sinkingFundPayment(
        futureValue: 12000,
        annualRate: 0,
        years: 1,
      ),
      1000,
    );
    final saving = CalculatorServices.sinkingFundPayment(
      futureValue: 100000,
      annualRate: 0.06,
      years: 5,
    );
    // Saving that amount at the end of each month grows to the goal.
    var value = 0.0;
    for (var month = 0; month < 60; month++) {
      value = value * 1.005 + saving;
    }
    expect(value, closeTo(100000, 1e-6));

    expect(
      CalculatorServices.annuityPayment(
        presentValue: 12000,
        annualRate: 0,
        years: 1,
      ),
      1000,
    );
    final payout = CalculatorServices.annuityPayment(
      presentValue: 100000,
      annualRate: 0.06,
      years: 30,
    );
    expect(
      payout,
      closeTo(
        CalculatorServices.loanPayment(
          principal: 100000,
          annualRate: 0.06,
          months: 360,
        ),
        1e-9,
      ),
    );
    expect(
      CalculatorServices.annuityPresentValue(
        payment: payout,
        annualRate: 0.06,
        periods: 360,
      ),
      closeTo(100000, 1e-6),
    );
    expect(
      () => CalculatorServices.annuityPayment(
        presentValue: 100000,
        annualRate: 0.06,
        years: 0,
      ),
      throwsArgumentError,
    );
  });

  test('fixed deposit pays simple interest less withholding tax', () {
    final deposit = CalculatorServices.fixedDeposit(
      principal: 100000,
      annualRate: 0.015,
      months: 12,
    );
    expect(deposit.grossInterest, closeTo(1500, 1e-9));
    expect(deposit.tax, closeTo(225, 1e-9));
    expect(deposit.maturityValue, closeTo(101275, 1e-9));
    expect(deposit.afterTaxYield, closeTo(0.01275, 1e-12));

    final sixMonths = CalculatorServices.fixedDeposit(
      principal: 100000,
      annualRate: 0.02,
      months: 6,
      withholdingRate: 0,
    );
    expect(sixMonths.grossInterest, closeTo(1000, 1e-9));
    expect(sixMonths.afterTaxYield, closeTo(0.02, 1e-12));
  });

  test('bond price and yield to maturity are inverses', () {
    expect(
      CalculatorServices.bondPrice(
        faceValue: 1000,
        couponRate: 0.05,
        yield: 0.05,
        years: 10,
      ),
      closeTo(1000, 1e-9),
    );
    final discount = CalculatorServices.bondPrice(
      faceValue: 1000,
      couponRate: 0.05,
      yield: 0.06,
      years: 10,
    );
    expect(discount, lessThan(1000));
    expect(
      CalculatorServices.bondYieldToMaturity(
        faceValue: 1000,
        couponRate: 0.05,
        price: discount,
        years: 10,
      ),
      closeTo(0.06, 1e-9),
    );
    expect(
      () => CalculatorServices.bondYieldToMaturity(
        faceValue: 1000,
        couponRate: 0.05,
        price: 1,
        years: 10,
      ),
      throwsArgumentError,
    );
  });

  test('internal rate of return makes the NPV zero', () {
    final flows = <double>[-1000, 300, 450, 600];
    final irr = CalculatorServices.internalRateOfReturn(flows)!;
    expect(
      CalculatorServices.netPresentValue(discountRate: irr, cashFlows: flows),
      closeTo(0, 1e-6),
    );
    expect(
      CalculatorServices.internalRateOfReturn([-100, 110]),
      closeTo(0.10, 1e-9),
    );
    expect(CalculatorServices.internalRateOfReturn([100, 200]), isNull);
  });
}
