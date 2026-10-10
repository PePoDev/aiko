import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/aiko_colors.dart';
import '../application/calculator_services.dart';
import '../application/thai_tax_rules.dart';
import 'calculator_form.dart';

/// The form for a calculator id from the library list, or null for an
/// unknown id. Labels and results are in [l10n]'s language.
CalculatorForm? calculatorForm(String id, AppLocalizations l10n) =>
    switch (id) {
      'Compound interest' => _compoundInterest(l10n),
      'Loan' => _loan(l10n),
      'Credit card payoff' => _creditCardPayoff(l10n),
      'Savings goal' => _savingsGoal(l10n),
      'ROI' => _roi(l10n),
      'Currency converter' => _currencyConverter(l10n),
      'Time value of money' => _timeValueOfMoney(l10n),
      'IRR / NPV' => _irrNpv(l10n),
      'Fixed deposit' => _fixedDeposit(l10n),
      'Bond yield' => _bondYield(l10n),
      'Tax equivalent yield' => _taxEquivalentYield(l10n),
      'Rule of 72' => _ruleOf72(l10n),
      'Bi-weekly mortgage payment' => _biweeklyMortgage(l10n),
      'Refinance savings' => _refinance(l10n),
      'Rent vs. buy' => _rentVsBuy(l10n),
      'Home affordability' => _homeAffordability(l10n),
      'Rental property cash flow' => _rentalCashFlow(l10n),
      'Tax-saving funds' => _taxSavingFunds(l10n),
      'Retirement drawdown' => _retirementDrawdown(l10n),
      'Social Security pension' => _socialSecurityPension(l10n),
      'Annuity payout' => _annuityPayout(l10n),
      'Car hire purchase vs. lease' => _carHirePurchase(l10n),
      'WACC' => _wacc(l10n),
      'Black-Scholes options' => _blackScholes(l10n),
      'CAPM' => _capm(l10n),
      'Capital gains tax' => _capitalGainsTax(l10n),
      'Salary to hourly' => _salaryToHourly(l10n),
      'Income tax' => _incomeTax(l10n),
      'Inflation' => _inflation(l10n),
      'Tip and percentage' => _tipPercentage(l10n),
      _ => null,
    };

/// Calculators built on Thai tax and social security rules work in baht.
const _baht = 'THB';
const _percent = '%';

// ---- Saving and investing ----

CalculatorForm _compoundInterest(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcConfigCompoundInterest,
  icon: Icons.trending_up,
  color: AikoColors.successGreen,
  fields: [
    CalculatorField(
      id: 'principal',
      label: l10n.calcFieldPrincipal,
      money: true,
    ),
    CalculatorField(
      id: 'monthlyContribution',
      label: l10n.calcFieldMonthlyContribution,
      money: true,
    ),
    CalculatorField(
      id: 'annualRate',
      label: l10n.calcFieldAnnualRate,
      suffixText: _percent,
    ),
    CalculatorField(
      id: 'years',
      label: l10n.calcFieldYears,
      allowsDecimal: false,
    ),
  ],
  calculate: (inputs) {
    final years = inputs.positiveInt('years');
    final futureValue = CalculatorServices.compoundInterest(
      principal: inputs.number('principal'),
      monthlyContribution: inputs.number(
        'monthlyContribution',
        allowZero: true,
      ),
      annualRate: inputs.percentage('annualRate'),
      years: years,
    );
    return CalculatorResult(
      title: l10n.calcResultFutureValue,
      value: inputs.money(futureValue),
      detail: l10n.calcResultFutureValueDetail(years),
      icon: Icons.trending_up,
      color: AikoColors.successGreen,
    );
  },
);

CalculatorForm _savingsGoal(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcConfigSavingsGoal,
  icon: Icons.flag_outlined,
  color: AikoColors.successGreen,
  fields: [
    CalculatorField(id: 'target', label: l10n.calcFieldTarget, money: true),
    CalculatorField(
      id: 'startingBalance',
      label: l10n.calcFieldStartingBalance,
      money: true,
      initialValue: '0',
    ),
    CalculatorField(
      id: 'monthlyContribution',
      label: l10n.calcFieldMonthlyContribution,
      money: true,
    ),
    CalculatorField(
      id: 'annualRate',
      label: l10n.calcFieldAnnualGrowth,
      suffixText: _percent,
      initialValue: '0',
    ),
  ],
  calculate: (inputs) {
    final monthlyContribution = inputs.number('monthlyContribution');
    final months = _monthsToSavingsGoal(
      l10n,
      target: inputs.number('target'),
      startingBalance: inputs.number('startingBalance', allowZero: true),
      monthlyContribution: monthlyContribution,
      annualRate: inputs.percentage('annualRate'),
    );
    return CalculatorResult(
      title: l10n.calcResultGoalTimeline,
      value: months == 0
          ? l10n.calcResultAlreadyFunded
          : l10n.monthsCount(months),
      detail: l10n.calcResultGoalDetail(inputs.money(monthlyContribution)),
      icon: Icons.flag_outlined,
      color: AikoColors.successGreen,
    );
  },
);

CalculatorForm _roi(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcConfigReturnOnInvestment,
  icon: Icons.show_chart,
  color: AikoColors.analyticsTeal,
  fields: [
    CalculatorField(
      id: 'initialInvestment',
      label: l10n.calcFieldInitialInvestment,
      money: true,
    ),
    CalculatorField(
      id: 'endingValue',
      label: l10n.calcFieldEndingValue,
      money: true,
    ),
    CalculatorField(
      id: 'fees',
      label: l10n.calcFieldFees,
      money: true,
      initialValue: '0',
    ),
    CalculatorField(
      id: 'income',
      label: l10n.calcFieldIncome,
      money: true,
      initialValue: '0',
    ),
  ],
  calculate: (inputs) {
    final initialInvestment = inputs.number('initialInvestment');
    final endingValue = inputs.number('endingValue');
    final fees = inputs.number('fees', allowZero: true);
    final income = inputs.number('income', allowZero: true);
    final roi = CalculatorServices.roi(
      initialInvestment: initialInvestment,
      endingValue: endingValue,
      fees: fees,
      income: income,
    );
    final gain = endingValue + income - fees - initialInvestment;
    return CalculatorResult(
      title: l10n.calcConfigReturnOnInvestment,
      value: inputs.percent(roi),
      detail: l10n.calcResultRoiDetail(inputs.money(gain)),
      icon: Icons.show_chart,
      color: AikoColors.analyticsTeal,
    );
  },
);

CalculatorForm _timeValueOfMoney(AppLocalizations l10n) {
  const futureValue = 'futureValue';
  const presentValue = 'presentValue';
  const monthlySaving = 'monthlySaving';
  return CalculatorForm(
    title: l10n.calcTitleTimeValueOfMoney,
    icon: Icons.schedule,
    color: AikoColors.analyticsTeal,
    fields: [
      CalculatorField(
        id: 'solveFor',
        label: l10n.calcFieldSolveFor,
        initialValue: futureValue,
        options: [
          CalculatorOption(futureValue, l10n.calcOptionFutureValue),
          CalculatorOption(presentValue, l10n.calcOptionPresentValue),
          CalculatorOption(monthlySaving, l10n.calcOptionMonthlySaving),
        ],
      ),
      CalculatorField(
        id: 'amountToday',
        label: l10n.calcFieldAmountToday,
        money: true,
        initialValue: '100000',
        showWhen: (field: 'solveFor', values: [futureValue]),
      ),
      CalculatorField(
        id: 'monthlyContribution',
        label: l10n.calcFieldMonthlyContribution,
        money: true,
        initialValue: '0',
        showWhen: (field: 'solveFor', values: [futureValue]),
      ),
      CalculatorField(
        id: 'futureAmount',
        label: l10n.calcFieldFutureAmount,
        money: true,
        initialValue: '1000000',
        showWhen: (field: 'solveFor', values: [presentValue, monthlySaving]),
      ),
      CalculatorField(
        id: 'annualRate',
        label: l10n.calcFieldAnnualRate,
        suffixText: _percent,
        initialValue: '5',
      ),
      CalculatorField(
        id: 'years',
        label: l10n.calcFieldYears,
        allowsDecimal: false,
        initialValue: '10',
      ),
    ],
    calculate: (inputs) {
      final annualRate = inputs.percentage('annualRate');
      final years = inputs.positiveInt('years');
      switch (inputs.choice('solveFor')) {
        case presentValue:
          final future = inputs.number('futureAmount');
          final present = CalculatorServices.presentValue(
            futureValue: future,
            annualRate: annualRate,
            years: years,
          );
          return CalculatorResult(
            title: l10n.calcOptionPresentValue,
            value: inputs.money(present),
            detail: l10n.calcResultPresentValueDetail(
              inputs.money(future),
              years,
              inputs.raw('annualRate'),
            ),
            icon: Icons.schedule,
            color: AikoColors.analyticsTeal,
          );
        case monthlySaving:
          final future = inputs.number('futureAmount');
          final saving = CalculatorServices.sinkingFundPayment(
            futureValue: future,
            annualRate: annualRate,
            years: years,
          );
          final contributed = saving * years * 12;
          return CalculatorResult(
            title: l10n.calcResultMonthlySaving,
            value: inputs.money(saving),
            detail: l10n.calcResultMonthlySavingDetail(
              inputs.money(future),
              years,
            ),
            icon: Icons.schedule,
            color: AikoColors.analyticsTeal,
            rows: [
              (
                label: l10n.calcRowTotalContributed,
                value: inputs.money(contributed),
              ),
              (
                label: l10n.calcRowEarnings,
                value: inputs.money(future - contributed),
              ),
            ],
          );
        default:
          final present = inputs.number('amountToday', allowZero: true);
          final monthly = inputs.number('monthlyContribution', allowZero: true);
          final future = CalculatorServices.compoundInterest(
            principal: present,
            monthlyContribution: monthly,
            annualRate: annualRate,
            years: years,
          );
          final contributed = present + monthly * years * 12;
          return CalculatorResult(
            title: l10n.calcResultFutureValue,
            value: inputs.money(future),
            detail: l10n.calcResultFutureValueDetail(years),
            icon: Icons.schedule,
            color: AikoColors.analyticsTeal,
            rows: [
              (
                label: l10n.calcRowTotalContributed,
                value: inputs.money(contributed),
              ),
              (
                label: l10n.calcRowEarnings,
                value: inputs.money(future - contributed),
              ),
            ],
          );
      }
    },
  );
}

CalculatorForm _irrNpv(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcConfigNetPresentValue,
  icon: Icons.analytics_outlined,
  color: AikoColors.analyticsTeal,
  fields: [
    CalculatorField(
      id: 'discountRate',
      label: l10n.calcFieldDiscountRate,
      suffixText: _percent,
      initialValue: '8',
    ),
    CalculatorField(
      id: 'cashFlows',
      label: l10n.calcFieldCashFlows,
      initialValue: '-1000, 300, 450, 600',
      text: true,
    ),
  ],
  calculate: (inputs) {
    final discountRate = inputs.percentage('discountRate');
    final cashFlowsText = inputs.raw('cashFlows');
    if (cashFlowsText.isEmpty) {
      throw CalculatorInputException(l10n.calcCashFlowsRequired);
    }
    final List<double> cashFlows;
    try {
      cashFlows = cashFlowsText
          .split(',')
          .map((s) => double.parse(s.trim()))
          .toList();
    } on FormatException {
      throw CalculatorInputException(l10n.calcCashFlowsFormat);
    }
    final npv = CalculatorServices.netPresentValue(
      discountRate: discountRate,
      cashFlows: cashFlows,
    );
    final irr = CalculatorServices.internalRateOfReturn(cashFlows);
    return CalculatorResult(
      title: l10n.calcResultNpv,
      value: inputs.money(npv),
      detail: l10n.calcResultNpvDetail(inputs.raw('discountRate')),
      icon: Icons.analytics_outlined,
      color: AikoColors.analyticsTeal,
      rows: [
        (
          label: l10n.calcRowIrr,
          value: irr == null ? l10n.calcIrrNone : inputs.percent(irr),
        ),
      ],
    );
  },
);

CalculatorForm _fixedDeposit(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleFixedDeposit,
  icon: Icons.savings_outlined,
  color: AikoColors.successGreen,
  fields: [
    CalculatorField(
      id: 'deposit',
      label: l10n.calcFieldDepositAmount,
      money: true,
      initialValue: '100000',
    ),
    CalculatorField(
      id: 'annualRate',
      label: l10n.calcFieldAnnualRate,
      suffixText: _percent,
      initialValue: '1.5',
    ),
    CalculatorField(
      id: 'months',
      label: l10n.calcFieldTermMonths,
      allowsDecimal: false,
      initialValue: '12',
    ),
    CalculatorField(
      id: 'withholdingTax',
      label: l10n.calcFieldWithholdingTax,
      suffixText: _percent,
      initialValue: '15',
      helper: l10n.calcHelperWithholdingTax,
    ),
  ],
  calculate: (inputs) {
    final deposit = CalculatorServices.fixedDeposit(
      principal: inputs.number('deposit'),
      annualRate: inputs.percentage('annualRate'),
      months: inputs.positiveInt('months'),
      withholdingRate: inputs.percentage('withholdingTax', atMost100: true),
    );
    return CalculatorResult(
      title: l10n.calcResultAtMaturity,
      value: inputs.money(deposit.maturityValue),
      detail: l10n.calcResultFixedDepositDetail,
      icon: Icons.savings_outlined,
      color: AikoColors.successGreen,
      rows: [
        (
          label: l10n.calcRowInterestEarned,
          value: inputs.money(deposit.grossInterest),
        ),
        (label: l10n.calcRowTaxWithheld, value: inputs.money(deposit.tax)),
        (
          label: l10n.calcRowAfterTaxYield,
          value: inputs.percent(deposit.afterTaxYield),
        ),
      ],
    );
  },
);

CalculatorForm _bondYield(AppLocalizations l10n) {
  const yieldFromPrice = 'yield';
  const priceFromYield = 'price';
  return CalculatorForm(
    title: l10n.calcTitleBondYield,
    icon: Icons.account_balance_outlined,
    color: AikoColors.deepBlue,
    fields: [
      CalculatorField(
        id: 'solveFor',
        label: l10n.calcFieldSolveFor,
        initialValue: yieldFromPrice,
        options: [
          CalculatorOption(yieldFromPrice, l10n.calcOptionYieldFromPrice),
          CalculatorOption(priceFromYield, l10n.calcOptionPriceFromYield),
        ],
      ),
      CalculatorField(
        id: 'faceValue',
        label: l10n.calcFieldFaceValue,
        money: true,
        initialValue: '1000',
      ),
      CalculatorField(
        id: 'couponRate',
        label: l10n.calcFieldCouponRate,
        suffixText: _percent,
        initialValue: '3',
      ),
      CalculatorField(
        id: 'years',
        label: l10n.calcFieldYearsToMaturity,
        initialValue: '5',
      ),
      CalculatorField(
        id: 'couponsPerYear',
        label: l10n.calcFieldCouponsPerYear,
        allowsDecimal: false,
        initialValue: '2',
        helper: l10n.calcHelperCouponsPerYear,
      ),
      CalculatorField(
        id: 'price',
        label: l10n.calcFieldBondPrice,
        money: true,
        initialValue: '980',
        showWhen: (field: 'solveFor', values: [yieldFromPrice]),
      ),
      CalculatorField(
        id: 'yield',
        label: l10n.calcFieldYieldToMaturity,
        suffixText: _percent,
        initialValue: '3.5',
        showWhen: (field: 'solveFor', values: [priceFromYield]),
      ),
    ],
    calculate: (inputs) {
      final faceValue = inputs.number('faceValue');
      final couponRate = inputs.percentage('couponRate');
      final years = inputs.number('years');
      final couponsPerYear = inputs.positiveInt('couponsPerYear');
      final annualCoupon = faceValue * couponRate;
      if (inputs.choice('solveFor') == priceFromYield) {
        final price = CalculatorServices.bondPrice(
          faceValue: faceValue,
          couponRate: couponRate,
          yield: inputs.percentage('yield'),
          years: years,
          periodsPerYear: couponsPerYear,
        );
        return CalculatorResult(
          title: l10n.calcResultBondPrice,
          value: inputs.money(price),
          detail: l10n.calcResultBondDetail,
          icon: Icons.account_balance_outlined,
          color: AikoColors.deepBlue,
          rows: [
            (
              label: l10n.calcRowPremiumDiscount,
              value: inputs.money(price - faceValue),
            ),
            (
              label: l10n.calcRowCurrentYield,
              value: inputs.percent(annualCoupon / price),
            ),
            (
              label: l10n.calcRowAnnualCoupon,
              value: inputs.money(annualCoupon),
            ),
          ],
        );
      }
      final price = inputs.number('price');
      final yieldToMaturity = CalculatorServices.bondYieldToMaturity(
        faceValue: faceValue,
        couponRate: couponRate,
        price: price,
        years: years,
        periodsPerYear: couponsPerYear,
      );
      return CalculatorResult(
        title: l10n.calcFieldYieldToMaturity,
        value: inputs.percent(yieldToMaturity),
        detail: l10n.calcResultBondDetail,
        icon: Icons.account_balance_outlined,
        color: AikoColors.deepBlue,
        rows: [
          (
            label: l10n.calcRowCurrentYield,
            value: inputs.percent(annualCoupon / price),
          ),
          (label: l10n.calcRowAnnualCoupon, value: inputs.money(annualCoupon)),
        ],
      );
    },
  );
}

CalculatorForm _taxEquivalentYield(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcConfigTaxEquivalentYield,
  icon: Icons.account_balance_wallet_outlined,
  color: AikoColors.warningOrange,
  fields: [
    CalculatorField(
      id: 'taxFreeYield',
      label: l10n.calcFieldTaxFreeYield,
      suffixText: _percent,
      initialValue: '3.5',
    ),
    CalculatorField(
      id: 'marginalTaxRate',
      label: l10n.calcFieldMarginalTaxRate,
      suffixText: _percent,
      initialValue: '24',
    ),
  ],
  calculate: (inputs) {
    final equivalent = CalculatorServices.taxEquivalentYield(
      taxFreeYield: inputs.percentage('taxFreeYield'),
      marginalTaxRate: inputs.percentage('marginalTaxRate'),
    );
    return CalculatorResult(
      title: l10n.calcConfigTaxEquivalentYield,
      value: inputs.percent(equivalent),
      detail: l10n.calcResultTeyDetail(
        inputs.raw('taxFreeYield'),
        inputs.raw('marginalTaxRate'),
      ),
      icon: Icons.account_balance_wallet_outlined,
      color: AikoColors.warningOrange,
    );
  },
);

CalculatorForm _ruleOf72(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcConfigRuleOf72,
  icon: Icons.timer_outlined,
  color: AikoColors.successGreen,
  fields: [
    CalculatorField(
      id: 'annualRate',
      label: l10n.calcFieldAnnualRate,
      suffixText: _percent,
      initialValue: '8',
    ),
  ],
  calculate: (inputs) {
    final years = CalculatorServices.ruleOf72(
      annualRate: inputs.percentage('annualRate'),
    );
    return CalculatorResult(
      title: l10n.calcResultYearsToDouble,
      value: l10n.calcYearsValue(inputs.decimal(years)),
      detail: l10n.calcResultRuleOf72Detail(inputs.raw('annualRate')),
      icon: Icons.timer_outlined,
      color: AikoColors.successGreen,
    );
  },
);

// ---- Debt, loans and cars ----

CalculatorForm _loan(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcConfigLoanPayment,
  icon: Icons.payments_outlined,
  color: AikoColors.deepBlue,
  fields: [
    CalculatorField(
      id: 'principal',
      label: l10n.calcFieldPrincipal,
      money: true,
    ),
    CalculatorField(
      id: 'annualRate',
      label: l10n.calcFieldAnnualRate,
      suffixText: _percent,
    ),
    CalculatorField(
      id: 'months',
      label: l10n.calcFieldTermMonths,
      allowsDecimal: false,
    ),
  ],
  calculate: (inputs) {
    final principal = inputs.number('principal');
    final months = inputs.positiveInt('months');
    final payment = CalculatorServices.loanPayment(
      principal: principal,
      annualRate: inputs.percentage('annualRate'),
      months: months,
    );
    final total = payment * months;
    return CalculatorResult(
      title: l10n.calcResultMonthlyPayment,
      value: inputs.money(payment),
      detail: l10n.calcResultLoanDetail(
        inputs.money(total),
        inputs.money(total - principal),
      ),
      icon: Icons.payments_outlined,
      color: AikoColors.deepBlue,
    );
  },
);

CalculatorForm _creditCardPayoff(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcConfigCreditCardPayoff,
  icon: Icons.credit_card_outlined,
  color: AikoColors.warningOrange,
  fields: [
    CalculatorField(id: 'balance', label: l10n.calcFieldBalance, money: true),
    CalculatorField(
      id: 'annualRate',
      label: l10n.calcFieldApr,
      suffixText: _percent,
    ),
    CalculatorField(
      id: 'monthlyPayment',
      label: l10n.calcFieldMonthlyPayment,
      money: true,
    ),
  ],
  calculate: (inputs) {
    final monthlyPayment = inputs.number('monthlyPayment');
    final payoff = _payoffMonths(
      l10n,
      balance: inputs.number('balance'),
      annualRate: inputs.percentage('annualRate'),
      monthlyPayment: monthlyPayment,
    );
    return CalculatorResult(
      title: l10n.calcResultPayoffEstimate,
      value: l10n.monthsCount(payoff.months),
      detail: l10n.calcResultPayoffDetail(
        inputs.money(payoff.interest),
        inputs.money(monthlyPayment),
      ),
      icon: Icons.credit_card_outlined,
      color: AikoColors.warningOrange,
    );
  },
);

CalculatorForm _carHirePurchase(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleCarHirePurchase,
  icon: Icons.directions_car_outlined,
  color: AikoColors.deepBlue,
  fields: [
    CalculatorField(
      id: 'price',
      label: l10n.calcFieldCarPrice,
      money: true,
      initialValue: '900000',
    ),
    CalculatorField(
      id: 'downPayment',
      label: l10n.calcFieldDownPayment,
      money: true,
      initialValue: '180000',
    ),
    CalculatorField(
      id: 'flatRate',
      label: l10n.calcFieldFlatRate,
      suffixText: _percent,
      initialValue: '2.5',
      helper: l10n.calcHelperFlatRate,
    ),
    CalculatorField(
      id: 'months',
      label: l10n.calcFieldTermMonths,
      allowsDecimal: false,
      initialValue: '60',
    ),
    CalculatorField(
      id: 'leasePayment',
      label: l10n.calcFieldLeasePayment,
      money: true,
      initialValue: '18000',
    ),
    CalculatorField(
      id: 'resaleValue',
      label: l10n.calcFieldResaleValue,
      money: true,
      initialValue: '400000',
      helper: l10n.calcHelperResaleValue,
    ),
  ],
  calculate: (inputs) {
    final price = inputs.number('price');
    final downPayment = inputs.number('downPayment', allowZero: true);
    if (downPayment > price) {
      throw CalculatorInputException(l10n.calcDownPaymentAbovePrice);
    }
    final car = CalculatorServices.hirePurchaseVsLease(
      price: price,
      downPayment: downPayment,
      flatRate: inputs.percentage('flatRate'),
      months: inputs.positiveInt('months'),
      leasePayment: inputs.number('leasePayment'),
      resaleValue: inputs.number('resaleValue', allowZero: true),
    );
    final hirePurchaseCheaper = car.buyCost <= car.leaseCost;
    return CalculatorResult(
      title: hirePurchaseCheaper
          ? l10n.calcResultHirePurchaseCheaper
          : l10n.calcResultLeaseCheaper,
      value: inputs.money((car.buyCost - car.leaseCost).abs()),
      detail: l10n.calcResultCarDetail,
      icon: Icons.directions_car_outlined,
      color: AikoColors.deepBlue,
      rows: [
        (label: l10n.calcRowInstallment, value: inputs.money(car.installment)),
        (
          label: l10n.calcRowTotalInterest,
          value: inputs.money(car.totalInterest),
        ),
        (
          label: l10n.calcRowEffectiveRate,
          value: inputs.percent(car.effectiveRate),
        ),
        (
          label: l10n.calcRowNetCostHirePurchase,
          value: inputs.money(car.buyCost),
        ),
        (label: l10n.calcRowLeaseTotal, value: inputs.money(car.leaseCost)),
      ],
    );
  },
);

// ---- Home and property ----

CalculatorForm _biweeklyMortgage(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleBiweeklyMortgage,
  icon: Icons.home_outlined,
  color: AikoColors.deepBlue,
  fields: [
    CalculatorField(
      id: 'loanAmount',
      label: l10n.calcFieldLoanAmount,
      money: true,
      initialValue: '3000000',
    ),
    CalculatorField(
      id: 'annualRate',
      label: l10n.calcFieldLoanRate,
      suffixText: _percent,
      initialValue: '6',
    ),
    CalculatorField(
      id: 'years',
      label: l10n.calcFieldTermYears,
      allowsDecimal: false,
      initialValue: '30',
    ),
  ],
  calculate: (inputs) {
    final plan = CalculatorServices.biweeklyMortgage(
      principal: inputs.number('loanAmount'),
      annualRate: inputs.percentage('annualRate'),
      years: inputs.positiveInt('years'),
    );
    return CalculatorResult(
      title: l10n.calcResultInterestSaved,
      value: inputs.money(
        plan.monthlyTotalInterest - plan.biweeklyTotalInterest,
      ),
      detail: l10n.calcResultBiweeklyDetail,
      icon: Icons.home_outlined,
      color: AikoColors.successGreen,
      rows: [
        (
          label: l10n.calcResultMonthlyPayment,
          value: inputs.money(plan.monthlyPayment),
        ),
        (
          label: l10n.calcRowBiweeklyPayment,
          value: inputs.money(plan.biweeklyPayment),
        ),
        (
          label: l10n.calcRowPaidOffIn,
          value: inputs.yearsMonths((plan.biweeklyYears * 12).ceil()),
        ),
        (
          label: l10n.calcRowInterestMonthly,
          value: inputs.money(plan.monthlyTotalInterest),
        ),
        (
          label: l10n.calcRowInterestBiweekly,
          value: inputs.money(plan.biweeklyTotalInterest),
        ),
      ],
    );
  },
);

CalculatorForm _refinance(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleRefinanceSavings,
  icon: Icons.compare_arrows,
  color: AikoColors.deepBlue,
  fields: [
    CalculatorField(
      id: 'balance',
      label: l10n.calcFieldCurrentBalance,
      money: true,
      initialValue: '2000000',
    ),
    CalculatorField(
      id: 'currentRate',
      label: l10n.calcFieldCurrentRate,
      suffixText: _percent,
      initialValue: '6.5',
    ),
    CalculatorField(
      id: 'remainingMonths',
      label: l10n.calcFieldRemainingMonths,
      allowsDecimal: false,
      initialValue: '240',
    ),
    CalculatorField(
      id: 'newRate',
      label: l10n.calcFieldNewRate,
      suffixText: _percent,
      initialValue: '5',
    ),
    CalculatorField(
      id: 'newMonths',
      label: l10n.calcFieldNewTermMonths,
      allowsDecimal: false,
      initialValue: '240',
    ),
    CalculatorField(
      id: 'closingCosts',
      label: l10n.calcFieldClosingCosts,
      money: true,
      initialValue: '30000',
      helper: l10n.calcHelperClosingCosts,
    ),
  ],
  calculate: (inputs) {
    final refinance = CalculatorServices.refinance(
      balance: inputs.number('balance'),
      currentRate: inputs.percentage('currentRate'),
      remainingMonths: inputs.positiveInt('remainingMonths'),
      newRate: inputs.percentage('newRate'),
      newMonths: inputs.positiveInt('newMonths'),
      closingCosts: inputs.number('closingCosts', allowZero: true),
    );
    final breakEven = refinance.breakEvenMonths;
    return CalculatorResult(
      title: l10n.calcResultTotalSavings,
      value: inputs.money(refinance.totalSavings),
      detail: l10n.calcResultRefinanceDetail,
      icon: Icons.compare_arrows,
      color: refinance.totalSavings >= 0
          ? AikoColors.successGreen
          : AikoColors.dangerRed,
      rows: [
        (
          label: l10n.calcRowCurrentPayment,
          value: inputs.money(refinance.currentPayment),
        ),
        (
          label: l10n.calcRowNewPayment,
          value: inputs.money(refinance.newPayment),
        ),
        (
          label: l10n.calcRowMonthlySaving,
          value: inputs.money(refinance.currentPayment - refinance.newPayment),
        ),
        (
          label: l10n.calcRowBreakEven,
          value: breakEven == null
              ? l10n.calcNeverBreaksEven
              : l10n.monthsCount(breakEven),
        ),
      ],
    );
  },
);

CalculatorForm _rentVsBuy(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleRentVsBuy,
  icon: Icons.real_estate_agent_outlined,
  color: AikoColors.deepBlue,
  fields: [
    CalculatorField(
      id: 'homePrice',
      label: l10n.calcFieldHomePrice,
      money: true,
      initialValue: '3000000',
    ),
    CalculatorField(
      id: 'downPayment',
      label: l10n.calcFieldDownPayment,
      suffixText: _percent,
      initialValue: '10',
    ),
    CalculatorField(
      id: 'loanRate',
      label: l10n.calcFieldLoanRate,
      suffixText: _percent,
      initialValue: '6',
    ),
    CalculatorField(
      id: 'loanYears',
      label: l10n.calcFieldTermYears,
      allowsDecimal: false,
      initialValue: '30',
    ),
    CalculatorField(
      id: 'monthlyRent',
      label: l10n.calcFieldMonthlyRent,
      money: true,
      initialValue: '12000',
    ),
    CalculatorField(
      id: 'years',
      label: l10n.calcFieldYearsToCompare,
      allowsDecimal: false,
      initialValue: '10',
    ),
    CalculatorField(
      id: 'homeGrowth',
      label: l10n.calcFieldHomeGrowth,
      suffixText: _percent,
      initialValue: '3',
    ),
    CalculatorField(
      id: 'rentIncrease',
      label: l10n.calcFieldRentIncrease,
      suffixText: _percent,
      initialValue: '3',
    ),
    CalculatorField(
      id: 'ownershipCosts',
      label: l10n.calcFieldOwnershipCosts,
      suffixText: _percent,
      initialValue: '1',
      helper: l10n.calcHelperOwnershipCosts,
    ),
    CalculatorField(
      id: 'investmentReturn',
      label: l10n.calcFieldInvestmentReturn,
      suffixText: _percent,
      initialValue: '4',
      helper: l10n.calcHelperInvestmentReturn,
    ),
  ],
  calculate: (inputs) {
    final years = inputs.positiveInt('years');
    final comparison = CalculatorServices.rentVsBuy(
      homePrice: inputs.number('homePrice'),
      downPaymentRate: inputs.percentage('downPayment', atMost100: true),
      loanRate: inputs.percentage('loanRate'),
      loanYears: inputs.positiveInt('loanYears'),
      monthlyRent: inputs.number('monthlyRent'),
      years: years,
      homeGrowthRate: inputs.percentage('homeGrowth'),
      rentGrowthRate: inputs.percentage('rentIncrease'),
      ownershipCostRate: inputs.percentage('ownershipCosts'),
      investmentReturn: inputs.percentage('investmentReturn'),
    );
    final buyingCheaper = comparison.buyCost <= comparison.rentCost;
    return CalculatorResult(
      title: buyingCheaper
          ? l10n.calcResultBuyingCheaper
          : l10n.calcResultRentingCheaper,
      value: inputs.money((comparison.buyCost - comparison.rentCost).abs()),
      detail: l10n.calcResultRentVsBuyDetail(years),
      icon: Icons.real_estate_agent_outlined,
      color: AikoColors.deepBlue,
      rows: [
        (
          label: l10n.calcRowNetCostBuying,
          value: inputs.money(comparison.buyCost),
        ),
        (
          label: l10n.calcRowNetCostRenting,
          value: inputs.money(comparison.rentCost),
        ),
        (
          label: l10n.calcRowHomeEquity,
          value: inputs.money(comparison.homeEquity),
        ),
      ],
    );
  },
);

CalculatorForm _homeAffordability(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleHomeAffordability,
  icon: Icons.house_outlined,
  color: AikoColors.deepBlue,
  fields: [
    CalculatorField(
      id: 'monthlyIncome',
      label: l10n.calcFieldMonthlyIncome,
      money: true,
      initialValue: '50000',
    ),
    CalculatorField(
      id: 'monthlyDebts',
      label: l10n.calcFieldMonthlyDebts,
      money: true,
      initialValue: '5000',
    ),
    CalculatorField(
      id: 'debtRatio',
      label: l10n.calcFieldDebtRatio,
      suffixText: _percent,
      initialValue: '40',
      helper: l10n.calcHelperDebtRatio,
    ),
    CalculatorField(
      id: 'annualRate',
      label: l10n.calcFieldLoanRate,
      suffixText: _percent,
      initialValue: '6',
    ),
    CalculatorField(
      id: 'years',
      label: l10n.calcFieldTermYears,
      allowsDecimal: false,
      initialValue: '30',
    ),
    CalculatorField(
      id: 'downPayment',
      label: l10n.calcFieldDownPayment,
      money: true,
      initialValue: '300000',
    ),
  ],
  calculate: (inputs) {
    final downPayment = inputs.number('downPayment', allowZero: true);
    final affordable = CalculatorServices.homeAffordability(
      monthlyIncome: inputs.number('monthlyIncome'),
      monthlyDebts: inputs.number('monthlyDebts', allowZero: true),
      debtRatio: inputs.percentage(
        'debtRatio',
        allowZero: false,
        atMost100: true,
      ),
      annualRate: inputs.percentage('annualRate'),
      months: inputs.positiveInt('years') * 12,
      downPayment: downPayment,
    );
    if (affordable.maxPayment <= 0) {
      throw CalculatorInputException(l10n.calcAffordabilityNoRoom);
    }
    return CalculatorResult(
      title: l10n.calcResultAffordablePrice,
      value: inputs.money(affordable.maxPrice),
      detail: l10n.calcResultAffordabilityDetail,
      icon: Icons.house_outlined,
      color: AikoColors.successGreen,
      rows: [
        (
          label: l10n.calcRowMaxPayment,
          value: inputs.money(affordable.maxPayment),
        ),
        (label: l10n.calcRowMaxLoan, value: inputs.money(affordable.maxLoan)),
        (label: l10n.calcFieldDownPayment, value: inputs.money(downPayment)),
      ],
    );
  },
);

CalculatorForm _rentalCashFlow(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleRentalCashFlow,
  icon: Icons.apartment,
  color: AikoColors.analyticsTeal,
  fields: [
    CalculatorField(
      id: 'price',
      label: l10n.calcFieldPropertyPrice,
      money: true,
      initialValue: '2500000',
    ),
    CalculatorField(
      id: 'monthlyRent',
      label: l10n.calcFieldMonthlyRent,
      money: true,
      initialValue: '15000',
    ),
    CalculatorField(
      id: 'vacancy',
      label: l10n.calcFieldVacancy,
      suffixText: _percent,
      initialValue: '5',
      helper: l10n.calcHelperVacancy,
    ),
    CalculatorField(
      id: 'monthlyCosts',
      label: l10n.calcFieldMonthlyCosts,
      money: true,
      initialValue: '2000',
      helper: l10n.calcHelperRentalCosts,
    ),
    CalculatorField(
      id: 'loanPayment',
      label: l10n.calcFieldMonthlyLoanPayment,
      money: true,
      initialValue: '0',
    ),
  ],
  calculate: (inputs) {
    final rental = CalculatorServices.rentalCashFlow(
      price: inputs.number('price'),
      monthlyRent: inputs.number('monthlyRent'),
      vacancyRate: inputs.percentage('vacancy', atMost100: true),
      monthlyCosts: inputs.number('monthlyCosts', allowZero: true),
      monthlyLoanPayment: inputs.number('loanPayment', allowZero: true),
    );
    return CalculatorResult(
      title: l10n.calcResultMonthlyCashFlow,
      value: inputs.money(rental.monthlyCashFlow),
      detail: l10n.calcResultRentalDetail,
      icon: Icons.apartment,
      color: rental.monthlyCashFlow >= 0
          ? AikoColors.successGreen
          : AikoColors.dangerRed,
      rows: [
        (
          label: l10n.calcRowNetOperatingIncome,
          value: inputs.money(rental.annualNetOperatingIncome),
        ),
        (label: l10n.calcRowCapRate, value: inputs.percent(rental.capRate)),
        (
          label: l10n.calcRowGrossYield,
          value: inputs.percent(rental.grossYield),
        ),
      ],
    );
  },
);

// ---- Retirement ----

CalculatorForm _taxSavingFunds(AppLocalizations l10n) {
  const rmf = 'rmf';
  const thaiEsg = 'thaiEsg';
  return CalculatorForm(
    title: l10n.calcTitleTaxSavingFunds,
    icon: Icons.elderly_outlined,
    color: AikoColors.successGreen,
    currency: _baht,
    fields: [
      CalculatorField(
        id: 'fund',
        label: l10n.calcFieldFund,
        initialValue: rmf,
        options: [
          CalculatorOption(rmf, l10n.calcOptionRmf),
          CalculatorOption(thaiEsg, l10n.calcOptionThaiEsg),
        ],
      ),
      CalculatorField(
        id: 'annualIncome',
        label: l10n.calcFieldAnnualIncome,
        money: true,
        initialValue: '600000',
      ),
      CalculatorField(
        id: 'yearlyPurchase',
        label: l10n.calcFieldYearlyPurchase,
        money: true,
        initialValue: '60000',
      ),
      CalculatorField(
        id: 'years',
        label: l10n.calcFieldYearsInvesting,
        allowsDecimal: false,
        initialValue: '10',
      ),
      CalculatorField(
        id: 'annualReturn',
        label: l10n.calcFieldExpectedReturn,
        suffixText: _percent,
        initialValue: '5',
      ),
      CalculatorField(
        id: 'otherDeductions',
        label: l10n.calcFieldOtherDeductions,
        money: true,
        initialValue: '10500',
        helper: l10n.calcHelperOtherDeductions,
      ),
    ],
    calculate: (inputs) {
      final isThaiEsg = inputs.choice('fund') == thaiEsg;
      final fund = CalculatorServices.taxSavingFund(
        annualIncome: inputs.number('annualIncome'),
        yearlyContribution: inputs.number('yearlyPurchase'),
        years: inputs.positiveInt('years'),
        annualReturn: inputs.percentage('annualReturn'),
        thaiEsg: isThaiEsg,
        otherDeductions: inputs.number('otherDeductions', allowZero: true),
      );
      return CalculatorResult(
        title: l10n.calcResultTaxSavedPerYear,
        value: inputs.money(fund.annualTaxSaving),
        detail: isThaiEsg
            ? l10n.calcResultThaiEsgDetail
            : l10n.calcResultRmfDetail,
        icon: Icons.elderly_outlined,
        color: AikoColors.successGreen,
        rows: [
          (label: l10n.calcRowDeductible, value: inputs.money(fund.deductible)),
          (
            label: l10n.calcRowWithTaxSavingFund,
            value: inputs.money(fund.fundValue + fund.refundsValue),
          ),
          (label: l10n.calcRowRegularFund, value: inputs.money(fund.fundValue)),
        ],
      );
    },
  );
}

CalculatorForm _retirementDrawdown(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleRetirementDrawdown,
  icon: Icons.event_repeat_outlined,
  color: AikoColors.premiumPurple,
  fields: [
    CalculatorField(
      id: 'savings',
      label: l10n.calcFieldSavingsAtRetirement,
      money: true,
      initialValue: '3000000',
    ),
    CalculatorField(
      id: 'monthlyWithdrawal',
      label: l10n.calcFieldMonthlyWithdrawal,
      money: true,
      initialValue: '20000',
    ),
    CalculatorField(
      id: 'annualReturn',
      label: l10n.calcFieldExpectedReturn,
      suffixText: _percent,
      initialValue: '4',
    ),
    CalculatorField(
      id: 'inflation',
      label: l10n.calcFieldAnnualInflation,
      suffixText: _percent,
      initialValue: '2',
      helper: l10n.calcHelperInflationWithdrawal,
    ),
    CalculatorField(
      id: 'retirementAge',
      label: l10n.calcFieldRetirementAge,
      allowsDecimal: false,
      initialValue: '60',
    ),
  ],
  calculate: (inputs) {
    final retirementAge = inputs.positiveInt('retirementAge');
    final drawdown = CalculatorServices.retirementDrawdown(
      savings: inputs.number('savings'),
      monthlyWithdrawal: inputs.number('monthlyWithdrawal'),
      annualReturn: inputs.percentage('annualReturn'),
      annualInflation: inputs.percentage('inflation'),
    );
    final months = drawdown.months.floor();
    return CalculatorResult(
      title: l10n.calcResultSavingsLast,
      value: drawdown.lastsForever
          ? l10n.calcOver100Years
          : inputs.yearsMonths(months),
      detail: l10n.calcResultDrawdownDetail,
      icon: Icons.event_repeat_outlined,
      color: AikoColors.premiumPurple,
      rows: [
        if (!drawdown.lastsForever) ...[
          (
            label: l10n.calcRowRunsOutAt,
            value: l10n.calcAgeValue(retirementAge + months ~/ 12),
          ),
          (
            label: l10n.calcRowTotalWithdrawn,
            value: inputs.money(drawdown.totalWithdrawn),
          ),
        ],
      ],
    );
  },
);

CalculatorForm _socialSecurityPension(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleSocialSecurity,
  icon: Icons.account_balance_wallet_outlined,
  color: AikoColors.premiumPurple,
  currency: _baht,
  fields: [
    CalculatorField(
      id: 'averageWage',
      label: l10n.calcFieldAverageWage,
      money: true,
      initialValue: '17500',
      helper: l10n.calcHelperAverageWage,
    ),
    CalculatorField(
      id: 'months',
      label: l10n.calcFieldMonthsContributed,
      allowsDecimal: false,
      initialValue: '240',
      helper: l10n.calcHelperMonthsContributed,
    ),
    CalculatorField(
      id: 'wageCeiling',
      label: l10n.calcFieldWageCeiling,
      money: true,
      initialValue: ThaiSocialSecurity.defaultWageCeiling.toStringAsFixed(0),
      helper: l10n.calcHelperWageCeiling,
    ),
  ],
  calculate: (inputs) {
    final averageWage = inputs.number('averageWage');
    final months = inputs.positiveInt('months');
    final ceiling = inputs.number('wageCeiling');
    final benefit = ThaiSocialSecurity.oldAgeBenefit(
      averageMonthlyWage: averageWage,
      monthsContributed: months,
      wageCeiling: ceiling,
    );
    final wageUsed = (
      label: l10n.calcRowWageUsed,
      value: inputs.money(math.min(averageWage, ceiling)),
    );
    final pension = benefit.monthlyPension;
    if (pension != null) {
      return CalculatorResult(
        title: l10n.calcResultMonthlyPension,
        value: inputs.money(pension),
        detail: l10n.calcResultPensionDetail,
        icon: Icons.account_balance_wallet_outlined,
        color: AikoColors.premiumPurple,
        rows: [
          (label: l10n.calcRowPensionRate, value: inputs.percent(benefit.rate)),
          wageUsed,
          (label: l10n.calcRowYearlyPension, value: inputs.money(pension * 12)),
        ],
      );
    }
    return CalculatorResult(
      title: l10n.calcResultLumpSum,
      value: inputs.money(benefit.lumpSum ?? 0),
      detail: l10n.calcResultLumpSumDetail,
      icon: Icons.account_balance_wallet_outlined,
      color: AikoColors.premiumPurple,
      rows: [
        (
          label: l10n.calcRowMonthsToPension,
          value: l10n.monthsCount(ThaiSocialSecurity.pensionMonths - months),
        ),
        wageUsed,
      ],
    );
  },
);

CalculatorForm _annuityPayout(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleAnnuityPayout,
  icon: Icons.payments,
  color: AikoColors.premiumPurple,
  fields: [
    CalculatorField(
      id: 'lumpSum',
      label: l10n.calcFieldLumpSum,
      money: true,
      initialValue: '2000000',
    ),
    CalculatorField(
      id: 'annualReturn',
      label: l10n.calcFieldExpectedReturn,
      suffixText: _percent,
      initialValue: '3',
    ),
    CalculatorField(
      id: 'years',
      label: l10n.calcFieldPayoutYears,
      allowsDecimal: false,
      initialValue: '20',
    ),
  ],
  calculate: (inputs) {
    final lumpSum = inputs.number('lumpSum');
    final years = inputs.positiveInt('years');
    final payment = CalculatorServices.annuityPayment(
      presentValue: lumpSum,
      annualRate: inputs.percentage('annualReturn'),
      years: years,
    );
    final total = payment * years * 12;
    return CalculatorResult(
      title: l10n.calcResultMonthlyPayout,
      value: inputs.money(payment),
      detail: l10n.calcResultAnnuityDetail(years),
      icon: Icons.payments,
      color: AikoColors.premiumPurple,
      rows: [
        (label: l10n.calcRowTotalPaidOut, value: inputs.money(total)),
        (label: l10n.calcRowEarnings, value: inputs.money(total - lumpSum)),
      ],
    );
  },
);

// ---- Business and markets ----

CalculatorForm _wacc(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleWacc,
  icon: Icons.business_center_outlined,
  color: AikoColors.analyticsTeal,
  fields: [
    CalculatorField(
      id: 'equityValue',
      label: l10n.calcFieldEquityValue,
      money: true,
      initialValue: '6000000',
    ),
    CalculatorField(
      id: 'debtValue',
      label: l10n.calcFieldDebtValue,
      money: true,
      initialValue: '4000000',
    ),
    CalculatorField(
      id: 'costOfEquity',
      label: l10n.calcFieldCostOfEquity,
      suffixText: _percent,
      initialValue: '10',
    ),
    CalculatorField(
      id: 'costOfDebt',
      label: l10n.calcFieldCostOfDebt,
      suffixText: _percent,
      initialValue: '5',
    ),
    CalculatorField(
      id: 'taxRate',
      label: l10n.calcFieldCorporateTaxRate,
      suffixText: _percent,
      initialValue: '20',
      helper: l10n.calcHelperCorporateTax,
    ),
  ],
  calculate: (inputs) {
    final equity = inputs.number('equityValue', allowZero: true);
    final debt = inputs.number('debtValue', allowZero: true);
    final costOfDebt = inputs.percentage('costOfDebt');
    final taxRate = inputs.percentage('taxRate', atMost100: true);
    final wacc = CalculatorServices.wacc(
      equityValue: equity,
      debtValue: debt,
      costOfEquity: inputs.percentage('costOfEquity'),
      costOfDebt: costOfDebt,
      taxRate: taxRate,
    );
    final total = equity + debt;
    return CalculatorResult(
      title: l10n.calcTitleWacc,
      value: inputs.percent(wacc),
      detail: l10n.calcResultWaccDetail,
      icon: Icons.business_center_outlined,
      color: AikoColors.analyticsTeal,
      rows: [
        (
          label: l10n.calcRowEquityWeight,
          value: inputs.percent(equity / total),
        ),
        (label: l10n.calcRowDebtWeight, value: inputs.percent(debt / total)),
        (
          label: l10n.calcRowAfterTaxCostOfDebt,
          value: inputs.percent(costOfDebt * (1 - taxRate)),
        ),
      ],
    );
  },
);

CalculatorForm _blackScholes(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleBlackScholes,
  icon: Icons.candlestick_chart,
  color: AikoColors.analyticsTeal,
  fields: [
    CalculatorField(
      id: 'spot',
      label: l10n.calcFieldSpotPrice,
      initialValue: '100',
    ),
    CalculatorField(
      id: 'strike',
      label: l10n.calcFieldStrikePrice,
      initialValue: '100',
    ),
    CalculatorField(
      id: 'years',
      label: l10n.calcFieldYearsToExpiry,
      initialValue: '1',
    ),
    CalculatorField(
      id: 'volatility',
      label: l10n.calcFieldVolatility,
      suffixText: _percent,
      initialValue: '20',
    ),
    CalculatorField(
      id: 'riskFreeRate',
      label: l10n.calcFieldRiskFreeRate,
      suffixText: _percent,
      initialValue: '2.5',
      helper: l10n.calcHelperRiskFreeRate,
    ),
    CalculatorField(
      id: 'dividendYield',
      label: l10n.calcFieldDividendYield,
      suffixText: _percent,
      initialValue: '0',
    ),
  ],
  calculate: (inputs) {
    final option = CalculatorServices.blackScholes(
      spot: inputs.number('spot'),
      strike: inputs.number('strike'),
      years: inputs.number('years'),
      volatility: inputs.percentage('volatility', allowZero: false),
      riskFreeRate: inputs.percentage('riskFreeRate'),
      dividendYield: inputs.percentage('dividendYield'),
    );
    return CalculatorResult(
      title: l10n.calcResultCallValue,
      value: inputs.decimal(option.call),
      detail: l10n.calcResultBlackScholesDetail,
      icon: Icons.candlestick_chart,
      color: AikoColors.analyticsTeal,
      rows: [(label: l10n.calcRowPutValue, value: inputs.decimal(option.put))],
    );
  },
);

CalculatorForm _capm(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleCapm,
  icon: Icons.timeline,
  color: AikoColors.analyticsTeal,
  fields: [
    CalculatorField(
      id: 'riskFreeRate',
      label: l10n.calcFieldRiskFreeRate,
      suffixText: _percent,
      initialValue: '2.5',
      helper: l10n.calcHelperRiskFreeRate,
    ),
    CalculatorField(id: 'beta', label: l10n.calcFieldBeta, initialValue: '1.2'),
    CalculatorField(
      id: 'marketReturn',
      label: l10n.calcFieldMarketReturn,
      suffixText: _percent,
      initialValue: '8',
    ),
  ],
  calculate: (inputs) {
    final riskFreeRate = inputs.percentage('riskFreeRate');
    final beta = inputs.number('beta', allowZero: true);
    final marketReturn = inputs.percentage('marketReturn');
    final expected = CalculatorServices.capm(
      riskFreeRate: riskFreeRate,
      beta: beta,
      marketReturn: marketReturn,
    );
    final marketPremium = marketReturn - riskFreeRate;
    return CalculatorResult(
      title: l10n.calcResultExpectedReturn,
      value: inputs.percent(expected),
      detail: l10n.calcResultCapmDetail,
      icon: Icons.timeline,
      color: AikoColors.analyticsTeal,
      rows: [
        (
          label: l10n.calcRowMarketPremium,
          value: inputs.percent(marketPremium),
        ),
        (
          label: l10n.calcRowRiskPremium,
          value: inputs.percent(beta * marketPremium),
        ),
      ],
    );
  },
);

// ---- Tax and income ----

CalculatorForm _capitalGainsTax(AppLocalizations l10n) {
  const exempt = 'exempt';
  const taxable = 'taxable';
  return CalculatorForm(
    title: l10n.calcTitleCapitalGains,
    icon: Icons.receipt_long_outlined,
    color: AikoColors.warningOrange,
    currency: _baht,
    fields: [
      CalculatorField(
        id: 'assetType',
        label: l10n.calcFieldAssetType,
        initialValue: exempt,
        options: [
          CalculatorOption(exempt, l10n.calcOptionThaiListed),
          CalculatorOption(taxable, l10n.calcOptionOtherAsset),
        ],
      ),
      CalculatorField(
        id: 'proceeds',
        label: l10n.calcFieldSaleProceeds,
        money: true,
        initialValue: '150000',
      ),
      CalculatorField(
        id: 'cost',
        label: l10n.calcFieldCostBasis,
        money: true,
        initialValue: '100000',
      ),
      CalculatorField(
        id: 'fees',
        label: l10n.calcFieldFees,
        money: true,
        initialValue: '0',
      ),
      CalculatorField(
        id: 'otherNetIncome',
        label: l10n.calcFieldOtherNetIncome,
        money: true,
        initialValue: '300000',
        helper: l10n.calcHelperOtherNetIncome,
        showWhen: (field: 'assetType', values: [taxable]),
      ),
    ],
    calculate: (inputs) {
      final isExempt = inputs.choice('assetType') == exempt;
      final sale = CalculatorServices.thaiCapitalGainsTax(
        proceeds: inputs.number('proceeds', allowZero: true),
        costBasis: inputs.number('cost', allowZero: true),
        fees: inputs.number('fees', allowZero: true),
        exempt: isExempt,
        otherNetIncome: isExempt
            ? 0
            : inputs.number('otherNetIncome', allowZero: true),
      );
      return CalculatorResult(
        title: l10n.calcResultAfterTaxProfit,
        value: inputs.money(sale.afterTaxProfit),
        detail: isExempt
            ? l10n.calcResultCapitalGainsExempt
            : l10n.calcResultCapitalGainsTaxed,
        icon: Icons.receipt_long_outlined,
        color: sale.afterTaxProfit >= 0
            ? AikoColors.successGreen
            : AikoColors.dangerRed,
        rows: [
          (label: l10n.calcRowGain, value: inputs.money(sale.gain)),
          (label: l10n.calcRowTax, value: inputs.money(sale.tax)),
        ],
      );
    },
  );
}

CalculatorForm _incomeTax(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcTitleIncomeTax,
  icon: Icons.request_quote_outlined,
  color: AikoColors.deepBlue,
  currency: _baht,
  fields: [
    CalculatorField(
      id: 'monthlySalary',
      label: l10n.calcFieldMonthlySalary,
      money: true,
      initialValue: '50000',
    ),
    CalculatorField(
      id: 'annualBonus',
      label: l10n.calcFieldAnnualBonus,
      money: true,
      initialValue: '0',
    ),
    CalculatorField(
      id: 'socialSecurity',
      label: l10n.calcFieldSocialSecurity,
      money: true,
      initialValue: '875',
      helper: l10n.calcHelperSocialSecurity,
    ),
    CalculatorField(
      id: 'otherDeductions',
      label: l10n.calcFieldOtherDeductions,
      money: true,
      initialValue: '0',
      helper: l10n.calcHelperOtherDeductionsNoSocialSecurity,
    ),
  ],
  calculate: (inputs) {
    final pay = CalculatorServices.thaiTakeHomePay(
      monthlySalary: inputs.number('monthlySalary'),
      annualBonus: inputs.number('annualBonus', allowZero: true),
      monthlySocialSecurity: inputs.number('socialSecurity', allowZero: true),
      otherDeductions: inputs.number('otherDeductions', allowZero: true),
    );
    return CalculatorResult(
      title: l10n.calcResultTakeHome,
      value: inputs.money(pay.takeHome),
      detail: l10n.calcResultIncomeTaxDetail,
      icon: Icons.request_quote_outlined,
      color: AikoColors.deepBlue,
      rows: [
        (
          label: l10n.calcRowAnnualIncome,
          value: inputs.money(pay.annualIncome),
        ),
        (label: l10n.calcRowTaxableIncome, value: inputs.money(pay.netIncome)),
        (label: l10n.calcRowAnnualTax, value: inputs.money(pay.annualTax)),
        (label: l10n.calcRowMonthlyTax, value: inputs.money(pay.monthlyTax)),
        (
          label: l10n.calcRowAverageTaxRate,
          value: inputs.percent(pay.effectiveRate),
        ),
        (
          label: l10n.calcRowTopBracket,
          value: inputs.percent(pay.marginalRate),
        ),
      ],
    );
  },
);

CalculatorForm _salaryToHourly(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcConfigSalaryToHourly,
  icon: Icons.work_outline,
  color: AikoColors.deepBlue,
  fields: [
    CalculatorField(
      id: 'annualSalary',
      label: l10n.calcFieldAnnualSalary,
      money: true,
      initialValue: '50000',
    ),
    CalculatorField(
      id: 'hoursPerWeek',
      label: l10n.calcFieldHoursPerWeek,
      initialValue: '40',
    ),
    CalculatorField(
      id: 'weeksPerYear',
      label: l10n.calcFieldWeeksPerYear,
      allowsDecimal: false,
      initialValue: '52',
    ),
  ],
  calculate: (inputs) {
    final hoursPerWeek = inputs.number('hoursPerWeek');
    final weeksPerYear = inputs.positiveInt('weeksPerYear');
    final hourly = CalculatorServices.salaryToHourly(
      annualSalary: inputs.number('annualSalary'),
      hoursPerWeek: hoursPerWeek,
      weeksPerYear: weeksPerYear.toDouble(),
    );
    return CalculatorResult(
      title: l10n.calcResultHourly,
      value: l10n.calcPerHourValue(inputs.money(hourly)),
      detail: l10n.calcResultHourlyDetail(hoursPerWeek, weeksPerYear),
      icon: Icons.work_outline,
      color: AikoColors.deepBlue,
    );
  },
);

// ---- Everyday ----

CalculatorForm _currencyConverter(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcConfigCurrencyConverter,
  icon: Icons.currency_exchange,
  color: AikoColors.analyticsTeal,
  fields: [
    CalculatorField(id: 'sourceAmount', label: l10n.calcFieldAmount),
    CalculatorField(id: 'exchangeRate', label: l10n.calcFieldExchangeRate),
  ],
  calculate: (inputs) {
    final exchangeRate = inputs.number('exchangeRate');
    final converted = CalculatorServices.convertCurrency(
      sourceAmount: inputs.number('sourceAmount'),
      exchangeRate: exchangeRate,
    );
    return CalculatorResult(
      title: l10n.calcResultConvertedAmount,
      value: inputs.decimal(converted),
      detail: l10n.calcResultConvertedDetail(inputs.decimal(exchangeRate)),
      icon: Icons.currency_exchange,
      color: AikoColors.analyticsTeal,
    );
  },
);

CalculatorForm _inflation(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcConfigInflationAdjusted,
  icon: Icons.money_off_csred_outlined,
  color: AikoColors.dangerRed,
  fields: [
    CalculatorField(
      id: 'amount',
      label: l10n.calcFieldCurrentAmount,
      money: true,
      initialValue: '1000',
    ),
    CalculatorField(
      id: 'annualInflationRate',
      label: l10n.calcFieldAnnualInflation,
      suffixText: _percent,
      initialValue: '3',
    ),
    CalculatorField(
      id: 'years',
      label: l10n.calcFieldYears,
      allowsDecimal: false,
      initialValue: '10',
    ),
  ],
  calculate: (inputs) {
    final amount = inputs.number('amount');
    final years = inputs.positiveInt('years');
    final adjusted = CalculatorServices.inflationAdjustedValue(
      amount: amount,
      annualInflationRate: inputs.percentage('annualInflationRate'),
      years: years,
    );
    return CalculatorResult(
      title: l10n.calcConfigInflationAdjusted,
      value: inputs.money(adjusted),
      detail: l10n.calcResultInflationDetail(
        inputs.money(amount),
        years,
        inputs.raw('annualInflationRate'),
      ),
      icon: Icons.money_off_csred_outlined,
      color: AikoColors.dangerRed,
    );
  },
);

CalculatorForm _tipPercentage(AppLocalizations l10n) => CalculatorForm(
  title: l10n.calcConfigTipSplit,
  icon: Icons.restaurant_outlined,
  color: AikoColors.successGreen,
  fields: [
    CalculatorField(
      id: 'bill',
      label: l10n.calcFieldBillAmount,
      money: true,
      initialValue: '50',
    ),
    CalculatorField(
      id: 'tipRate',
      label: l10n.calcFieldTipRate,
      suffixText: _percent,
      initialValue: '15',
    ),
    CalculatorField(
      id: 'splitCount',
      label: l10n.calcFieldSplitCount,
      allowsDecimal: false,
      initialValue: '1',
    ),
  ],
  calculate: (inputs) {
    final bill = inputs.number('bill');
    final splitCount = inputs.positiveInt('splitCount');
    final tip = CalculatorServices.tipAmount(
      bill: bill,
      tipRate: inputs.percentage('tipRate'),
    );
    final total = bill + tip;
    return CalculatorResult(
      title: l10n.calcResultSplitSummary,
      value: l10n.calcEachValue(inputs.money(total / splitCount)),
      detail: l10n.calcResultTipDetail(
        inputs.money(tip),
        inputs.money(total),
        splitCount,
      ),
      icon: Icons.restaurant_outlined,
      color: AikoColors.successGreen,
    );
  },
);

// ---- Helpers ----

({int months, double interest}) _payoffMonths(
  AppLocalizations l10n, {
  required double balance,
  required double annualRate,
  required double monthlyPayment,
}) {
  final monthlyRate = annualRate / 12;
  var remaining = balance;
  var interestPaid = 0.0;
  var months = 0;
  while (remaining > 0.01 && months < 1200) {
    final interest = remaining * monthlyRate;
    if (monthlyPayment <= interest) {
      throw CalculatorInputException(l10n.calcPaymentTooLow);
    }
    interestPaid += interest;
    remaining = remaining + interest - monthlyPayment;
    months++;
  }
  if (months >= 1200) {
    throw CalculatorInputException(l10n.calcPayoffTooLong);
  }
  return (months: months, interest: interestPaid);
}

int _monthsToSavingsGoal(
  AppLocalizations l10n, {
  required double target,
  required double startingBalance,
  required double monthlyContribution,
  required double annualRate,
}) {
  if (startingBalance >= target) return 0;
  final monthlyRate = annualRate / 12;
  var value = startingBalance;
  var months = 0;
  while (value < target && months < 1200) {
    value = (value + monthlyContribution) * (1 + monthlyRate);
    months++;
  }
  if (months >= 1200) {
    throw CalculatorInputException(l10n.calcGoalTooLong);
  }
  return months;
}
