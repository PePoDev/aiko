import 'package:aiko/features/calculators/application/calculator_services.dart';
import 'package:aiko/features/calculators/application/thai_tax_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThaiIncomeTax', () {
    test('taxes each bracket at its own rate', () {
      expect(ThaiIncomeTax.taxOn(0), 0);
      expect(ThaiIncomeTax.taxOn(150000), 0);
      expect(ThaiIncomeTax.taxOn(300000), 7500);
      expect(ThaiIncomeTax.taxOn(500000), 27500);
      expect(ThaiIncomeTax.taxOn(750000), 65000);
      expect(ThaiIncomeTax.taxOn(1000000), 115000);
      expect(ThaiIncomeTax.taxOn(2000000), 365000);
      expect(ThaiIncomeTax.taxOn(5000000), 1265000);
      expect(ThaiIncomeTax.taxOn(6000000), 1615000);
      expect(ThaiIncomeTax.taxOn(-1000), 0);
    });

    test('marginal rate is the rate on the next baht', () {
      expect(ThaiIncomeTax.marginalRate(100000), 0);
      expect(ThaiIncomeTax.marginalRate(150000), 0.05);
      expect(ThaiIncomeTax.marginalRate(431000), 0.10);
      expect(ThaiIncomeTax.marginalRate(9000000), 0.35);
    });

    test('deducts expenses, the personal allowance and other deductions', () {
      expect(ThaiIncomeTax.employmentExpenseDeduction(120000), 60000);
      expect(ThaiIncomeTax.employmentExpenseDeduction(600000), 100000);
      expect(
        ThaiIncomeTax.netEmploymentIncome(600000, otherDeductions: 9000),
        431000,
      );
      expect(ThaiIncomeTax.netEmploymentIncome(100000), 0);
    });

    test('caps RMF and Thai ESG deductions', () {
      expect(
        ThaiIncomeTax.fundDeductionCap(annualIncome: 600000, thaiEsg: false),
        180000,
      );
      expect(
        ThaiIncomeTax.fundDeductionCap(annualIncome: 3000000, thaiEsg: false),
        500000,
      );
      expect(
        ThaiIncomeTax.fundDeductionCap(annualIncome: 3000000, thaiEsg: true),
        300000,
      );
    });
  });

  group('ThaiSocialSecurity', () {
    test('pays a pension from 180 months, rising 1.5% a year beyond', () {
      final base = ThaiSocialSecurity.oldAgeBenefit(
        averageMonthlyWage: 20000,
        monthsContributed: 180,
      );
      // Capped at the 17,500 baht ceiling.
      expect(base.monthlyPension, 3500);
      expect(base.lumpSum, isNull);
      expect(base.rate, 0.20);

      final partYear = ThaiSocialSecurity.oldAgeBenefit(
        averageMonthlyWage: 15000,
        monthsContributed: 191,
      );
      expect(partYear.monthlyPension, 3000);

      final longer = ThaiSocialSecurity.oldAgeBenefit(
        averageMonthlyWage: 15000,
        monthsContributed: 240,
      );
      expect(longer.rate, closeTo(0.275, 1e-12));
      expect(longer.monthlyPension, closeTo(4125, 1e-9));
    });

    test('uses the wage ceiling the caller gives', () {
      final benefit = ThaiSocialSecurity.oldAgeBenefit(
        averageMonthlyWage: 20000,
        monthsContributed: 180,
        wageCeiling: 15000,
      );
      expect(benefit.monthlyPension, 3000);
    });

    test('pays a lump sum below 180 months', () {
      final belowYear = ThaiSocialSecurity.oldAgeBenefit(
        averageMonthlyWage: 10000,
        monthsContributed: 6,
      );
      expect(belowYear.monthlyPension, isNull);
      expect(belowYear.lumpSum, closeTo(1800, 1e-9));

      final tenYears = ThaiSocialSecurity.oldAgeBenefit(
        averageMonthlyWage: 15000,
        monthsContributed: 120,
      );
      expect(tenYears.lumpSum, closeTo(108000, 1e-9));
    });
  });

  group('Thai tax calculators', () {
    test('take-home pay spreads the year\'s tax over 12 months', () {
      final pay = CalculatorServices.thaiTakeHomePay(
        monthlySalary: 50000,
        monthlySocialSecurity: 750,
      );
      expect(pay.annualIncome, 600000);
      expect(pay.netIncome, 431000);
      expect(pay.annualTax, closeTo(20600, 1e-9));
      expect(pay.monthlyTax, closeTo(1716.67, 0.01));
      expect(pay.takeHome, closeTo(47533.33, 0.01));
      expect(pay.effectiveRate, closeTo(20600 / 600000, 1e-12));
      expect(pay.marginalRate, 0.10);
    });

    test('a bonus and other deductions change the tax', () {
      final pay = CalculatorServices.thaiTakeHomePay(
        monthlySalary: 50000,
        annualBonus: 100000,
        monthlySocialSecurity: 750,
        otherDeductions: 31000,
      );
      // 700,000 − 100,000 − 60,000 − 9,000 − 31,000 = 500,000.
      expect(pay.netIncome, 500000);
      expect(pay.annualTax, closeTo(27500, 1e-9));
    });

    test('capital gains are exempt or taxed on top of other income', () {
      final taxed = CalculatorServices.thaiCapitalGainsTax(
        proceeds: 150000,
        costBasis: 100000,
        fees: 1000,
        exempt: false,
        otherNetIncome: 431000,
      );
      expect(taxed.gain, 49000);
      expect(taxed.tax, closeTo(4900, 1e-9));
      expect(taxed.afterTaxProfit, closeTo(44100, 1e-9));

      final exempt = CalculatorServices.thaiCapitalGainsTax(
        proceeds: 150000,
        costBasis: 100000,
        exempt: true,
      );
      expect(exempt.tax, 0);
      expect(exempt.afterTaxProfit, 50000);

      final loss = CalculatorServices.thaiCapitalGainsTax(
        proceeds: 80000,
        costBasis: 100000,
        exempt: false,
      );
      expect(loss.gain, -20000);
      expect(loss.tax, 0);
    });

    test('tax-saving funds save tax at the marginal rate up to the cap', () {
      final rmf = CalculatorServices.taxSavingFund(
        annualIncome: 600000,
        yearlyContribution: 100000,
        years: 1,
        annualReturn: 0,
        thaiEsg: false,
      );
      expect(rmf.deductible, 100000);
      expect(rmf.annualTaxSaving, closeTo(10000, 1e-9));
      expect(rmf.fundValue, 100000);
      expect(rmf.refundsValue, closeTo(10000, 1e-9));

      final capped = CalculatorServices.taxSavingFund(
        annualIncome: 600000,
        yearlyContribution: 400000,
        years: 2,
        annualReturn: 0.10,
        thaiEsg: true,
      );
      expect(capped.deductible, 180000);
      expect(capped.fundValue, closeTo((400000 * 1.1 + 400000) * 1.1, 1e-6));
      expect(capped.refundsValue, closeTo(capped.annualTaxSaving * 2.1, 1e-6));
    });

    test('tax-saving funds reject a zero term', () {
      expect(
        () => CalculatorServices.taxSavingFund(
          annualIncome: 600000,
          yearlyContribution: 100000,
          years: 0,
          annualReturn: 0,
          thaiEsg: false,
        ),
        throwsArgumentError,
      );
    });
  });
}
