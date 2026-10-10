import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/calculator_services.dart';

class CalculatorDetailScreen extends ConsumerStatefulWidget {
  const CalculatorDetailScreen({
    required this.calculatorId,
    required this.title,
    super.key,
  });

  /// Stable English id from the calculator library.
  final String calculatorId;

  /// Title in the current language.
  final String title;

  @override
  ConsumerState<CalculatorDetailScreen> createState() =>
      _CalculatorDetailScreenState();
}

class _CalculatorDetailScreenState
    extends ConsumerState<CalculatorDetailScreen> {
  late _CalculatorConfig _config;
  late Map<String, TextEditingController> _controllers;
  _CalculationResult? _result;

  @override
  void initState() {
    super.initState();
    _config = _CalculatorConfig.fromId(widget.calculatorId, currentL10n());
    _controllers = {
      for (final field in _config.fields)
        field.id: TextEditingController(text: field.initialValue),
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Same fields and ids; labels in the current language.
    _config = _CalculatorConfig.fromId(widget.calculatorId, context.l10n);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    try {
      final result = switch (_config.kind) {
        _CalculatorKind.compoundInterest => _compoundInterest(),
        _CalculatorKind.loan => _loanPayment(),
        _CalculatorKind.creditCardPayoff => _creditCardPayoff(),
        _CalculatorKind.savingsGoal => _savingsGoal(),
        _CalculatorKind.roi => _roi(),
        _CalculatorKind.currencyConverter => _currencyConverter(),
        _CalculatorKind.ruleOf72 => _ruleOf72(),
        _CalculatorKind.inflation => _inflation(),
        _CalculatorKind.salaryToHourly => _salaryToHourly(),
        _CalculatorKind.taxEquivalentYield => _taxEquivalentYield(),
        _CalculatorKind.irrNpv => _irrNpv(),
        _CalculatorKind.tipPercentage => _tipPercentage(),
      };

      setState(() => _result = result);
    } on _CalculatorInputException catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_argumentErrorMessage(error, context.l10n))),
      );
    }
  }

  /// [CalculatorServices] validation errors in the user's language.
  String _argumentErrorMessage(ArgumentError error, AppLocalizations l10n) {
    return switch ('${error.message}') {
      'Term must be positive.' => l10n.calcErrorTermPositive,
      'Initial investment must be positive.' =>
        l10n.calcErrorInvestmentPositive,
      'Exchange rate must be positive.' => l10n.calcErrorRatePositive,
      'Annual rate must be positive.' => l10n.calcErrorAnnualRatePositive,
      'Marginal tax rate must be below 100%.' => l10n.calcErrorTaxRateBelow100,
      _ => l10n.calcErrorGeneric,
    };
  }

  _CalculationResult _compoundInterest() {
    final principal = _positiveNumber('principal');
    final monthlyContribution = _number('monthlyContribution', allowZero: true);
    final annualRate = _percentage('annualRate');
    final years = _positiveInt('years');

    final futureValue = CalculatorServices.compoundInterest(
      principal: principal,
      monthlyContribution: monthlyContribution,
      annualRate: annualRate,
      years: years,
    );

    return _CalculationResult(
      title: context.l10n.calcResultFutureValue,
      value: _formatCurrency(futureValue),
      detail: context.l10n.calcResultFutureValueDetail(years),
      icon: Icons.trending_up,
      color: AikoColors.successGreen,
    );
  }

  _CalculationResult _loanPayment() {
    final principal = _positiveNumber('principal');
    final annualRate = _percentage('annualRate');
    final months = _positiveInt('months');

    final payment = CalculatorServices.loanPayment(
      principal: principal,
      annualRate: annualRate,
      months: months,
    );
    final total = payment * months;

    return _CalculationResult(
      title: context.l10n.calcResultMonthlyPayment,
      value: _formatCurrency(payment),
      detail: context.l10n.calcResultLoanDetail(
        _formatCurrency(total),
        _formatCurrency(total - principal),
      ),
      icon: Icons.payments_outlined,
      color: AikoColors.deepBlue,
    );
  }

  _CalculationResult _creditCardPayoff() {
    final balance = _positiveNumber('balance');
    final annualRate = _percentage('annualRate');
    final monthlyPayment = _positiveNumber('monthlyPayment');
    final payoff = _payoffMonths(
      balance: balance,
      annualRate: annualRate,
      monthlyPayment: monthlyPayment,
    );

    return _CalculationResult(
      title: context.l10n.calcResultPayoffEstimate,
      value: context.l10n.monthsCount(payoff.months),
      detail: context.l10n.calcResultPayoffDetail(
        _formatCurrency(payoff.interest),
        _formatCurrency(monthlyPayment),
      ),
      icon: Icons.credit_card_outlined,
      color: AikoColors.warningOrange,
    );
  }

  _CalculationResult _savingsGoal() {
    final target = _positiveNumber('target');
    final startingBalance = _number('startingBalance', allowZero: true);
    final monthlyContribution = _positiveNumber('monthlyContribution');
    final annualRate = _percentage('annualRate');
    final months = _monthsToSavingsGoal(
      target: target,
      startingBalance: startingBalance,
      monthlyContribution: monthlyContribution,
      annualRate: annualRate,
    );

    return _CalculationResult(
      title: context.l10n.calcResultGoalTimeline,
      value: months == 0
          ? context.l10n.calcResultAlreadyFunded
          : context.l10n.monthsCount(months),
      detail: context.l10n.calcResultGoalDetail(
        _formatCurrency(monthlyContribution),
      ),
      icon: Icons.flag_outlined,
      color: AikoColors.successGreen,
    );
  }

  _CalculationResult _roi() {
    final initialInvestment = _positiveNumber('initialInvestment');
    final endingValue = _positiveNumber('endingValue');
    final fees = _number('fees', allowZero: true);
    final income = _number('income', allowZero: true);

    final roi = CalculatorServices.roi(
      initialInvestment: initialInvestment,
      endingValue: endingValue,
      fees: fees,
      income: income,
    );
    final gain = endingValue + income - fees - initialInvestment;

    return _CalculationResult(
      title: context.l10n.calcConfigReturnOnInvestment,
      value: _formatPercent(roi),
      detail: context.l10n.calcResultRoiDetail(_formatCurrency(gain)),
      icon: Icons.show_chart,
      color: AikoColors.analyticsTeal,
    );
  }

  _CalculationResult _currencyConverter() {
    final sourceAmount = _positiveNumber('sourceAmount');
    final exchangeRate = _positiveNumber('exchangeRate');
    final converted = CalculatorServices.convertCurrency(
      sourceAmount: sourceAmount,
      exchangeRate: exchangeRate,
    );

    return _CalculationResult(
      title: context.l10n.calcResultConvertedAmount,
      value: _formatNumber(converted),
      detail: context.l10n.calcResultConvertedDetail(
        _formatNumber(exchangeRate),
      ),
      icon: Icons.currency_exchange,
      color: AikoColors.analyticsTeal,
    );
  }

  _CalculationResult _ruleOf72() {
    final annualRate = _percentage('annualRate');
    final years = CalculatorServices.ruleOf72(annualRate: annualRate);

    return _CalculationResult(
      title: context.l10n.calcResultYearsToDouble,
      value: context.l10n.calcYearsValue(_formatNumber(years)),
      detail: context.l10n.calcResultRuleOf72Detail(
        _controllers['annualRate']!.text,
      ),
      icon: Icons.timer_outlined,
      color: AikoColors.successGreen,
    );
  }

  _CalculationResult _inflation() {
    final amount = _positiveNumber('amount');
    final annualInflationRate = _percentage('annualInflationRate');
    final years = _positiveInt('years');

    final adjusted = CalculatorServices.inflationAdjustedValue(
      amount: amount,
      annualInflationRate: annualInflationRate,
      years: years,
    );

    return _CalculationResult(
      title: context.l10n.calcConfigInflationAdjusted,
      value: _formatCurrency(adjusted),
      detail: context.l10n.calcResultInflationDetail(
        _formatCurrency(amount),
        years,
        _controllers['annualInflationRate']!.text,
      ),
      icon: Icons.money_off_csred_outlined,
      color: AikoColors.dangerRed,
    );
  }

  _CalculationResult _salaryToHourly() {
    final annualSalary = _positiveNumber('annualSalary');
    final hoursPerWeek = _positiveNumber('hoursPerWeek');
    final weeksPerYear = _positiveInt('weeksPerYear');

    final hourly = CalculatorServices.salaryToHourly(
      annualSalary: annualSalary,
      hoursPerWeek: hoursPerWeek,
      weeksPerYear: weeksPerYear.toDouble(),
    );

    return _CalculationResult(
      title: context.l10n.calcResultHourly,
      value: context.l10n.calcPerHourValue(_formatCurrency(hourly)),
      detail: context.l10n.calcResultHourlyDetail(hoursPerWeek, weeksPerYear),
      icon: Icons.work_outline,
      color: AikoColors.deepBlue,
    );
  }

  _CalculationResult _taxEquivalentYield() {
    final taxFreeYield = _percentage('taxFreeYield');
    final marginalTaxRate = _percentage('marginalTaxRate');

    final equivalent = CalculatorServices.taxEquivalentYield(
      taxFreeYield: taxFreeYield,
      marginalTaxRate: marginalTaxRate,
    );

    return _CalculationResult(
      title: context.l10n.calcConfigTaxEquivalentYield,
      value: _formatPercent(equivalent),
      detail: context.l10n.calcResultTeyDetail(
        _controllers['taxFreeYield']!.text,
        _controllers['marginalTaxRate']!.text,
      ),
      icon: Icons.account_balance_wallet_outlined,
      color: AikoColors.warningOrange,
    );
  }

  _CalculationResult _irrNpv() {
    final discountRate = _percentage('discountRate');
    final cashFlowsText = _controllers['cashFlows']!.text.trim();
    if (cashFlowsText.isEmpty) {
      throw _CalculatorInputException(context.l10n.calcCashFlowsRequired);
    }
    final List<double> cashFlows;
    try {
      cashFlows = cashFlowsText
          .split(',')
          .map((s) => double.parse(s.trim()))
          .toList();
    } catch (_) {
      throw _CalculatorInputException(context.l10n.calcCashFlowsFormat);
    }

    final npv = CalculatorServices.netPresentValue(
      discountRate: discountRate,
      cashFlows: cashFlows,
    );

    return _CalculationResult(
      title: context.l10n.calcResultNpv,
      value: _formatCurrency(npv),
      detail: context.l10n.calcResultNpvDetail(
        _controllers['discountRate']!.text,
      ),
      icon: Icons.analytics_outlined,
      color: AikoColors.analyticsTeal,
    );
  }

  _CalculationResult _tipPercentage() {
    final bill = _positiveNumber('bill');
    final tipRate = _percentage('tipRate');
    final splitCount = _positiveInt('splitCount');

    final tip = CalculatorServices.tipAmount(bill: bill, tipRate: tipRate);
    final total = bill + tip;
    final perPerson = total / splitCount;

    return _CalculationResult(
      title: context.l10n.calcResultSplitSummary,
      value: context.l10n.calcEachValue(_formatCurrency(perPerson)),
      detail: context.l10n.calcResultTipDetail(
        _formatCurrency(tip),
        _formatCurrency(total),
        splitCount,
      ),
      icon: Icons.restaurant_outlined,
      color: AikoColors.successGreen,
    );
  }

  double _positiveNumber(String id) => _number(id);

  double _number(String id, {bool allowZero = false}) {
    final field = _config.fieldFor(id);
    final value = double.tryParse(
      _controllers[id]!.text.trim().replaceAll(',', ''),
    );
    if (value == null) {
      throw _CalculatorInputException(context.l10n.calcEnterValid(field.label));
    }
    if (allowZero ? value < 0 : value <= 0) {
      throw _CalculatorInputException(
        context.l10n.calcMustBePositive(field.label),
      );
    }
    return value;
  }

  int _positiveInt(String id) {
    final field = _config.fieldFor(id);
    final value = int.tryParse(_controllers[id]!.text.trim());
    if (value == null || value <= 0) {
      throw _CalculatorInputException(context.l10n.calcEnterValid(field.label));
    }
    return value;
  }

  double _percentage(String id) {
    final field = _config.fieldFor(id);
    final value = double.tryParse(
      _controllers[id]!.text.trim().replaceAll(',', ''),
    );
    if (value == null || value < 0) {
      throw _CalculatorInputException(context.l10n.calcEnterValid(field.label));
    }
    return value / 100;
  }

  _PayoffResult _payoffMonths({
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
        throw _CalculatorInputException(context.l10n.calcPaymentTooLow);
      }
      interestPaid += interest;
      remaining = remaining + interest - monthlyPayment;
      months++;
    }

    if (months >= 1200) {
      throw _CalculatorInputException(context.l10n.calcPayoffTooLong);
    }

    return _PayoffResult(months: months, interest: interestPaid);
  }

  int _monthsToSavingsGoal({
    required double target,
    required double startingBalance,
    required double monthlyContribution,
    required double annualRate,
  }) {
    if (startingBalance >= target) {
      return 0;
    }

    final monthlyRate = annualRate / 12;
    var value = startingBalance;
    var months = 0;

    while (value < target && months < 1200) {
      value = (value + monthlyContribution) * (1 + monthlyRate);
      months++;
    }

    if (months >= 1200) {
      throw _CalculatorInputException(context.l10n.calcGoalTooLong);
    }

    return months;
  }

  String get _baseCurrency =>
      ref.read(profileProvider).value?.baseCurrency ?? kDefaultBaseCurrency;

  String get _currencySymbol =>
      NumberFormat.simpleCurrency(name: _baseCurrency).currencySymbol;

  String _formatCurrency(double value) {
    return NumberFormat.simpleCurrency(name: _baseCurrency).format(value);
  }

  String _formatPercent(double value) {
    return NumberFormat.decimalPercentPattern(decimalDigits: 2).format(value);
  }

  String _formatNumber(double value) {
    return NumberFormat.decimalPatternDigits(decimalDigits: 2).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          FinanceCard(
            title: _config.title,
            icon: _config.icon,
            accentColor: _config.color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in _config.fields) ...[
                  TextField(
                    controller: _controllers[field.id],
                    decoration: InputDecoration(
                      labelText: field.label,
                      prefixText: field.money ? '$_currencySymbol ' : null,
                      suffixText: field.suffixText,
                    ),
                    keyboardType: field.id == 'cashFlows'
                        ? TextInputType.text
                        : TextInputType.numberWithOptions(
                            decimal: field.allowsDecimal,
                          ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.calculate_outlined),
                  label: Text(context.l10n.calcCalculate),
                ),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            FinanceCard(
              title: _result!.title,
              icon: _result!.icon,
              accentColor: _result!.color,
              prominent: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AmountText(_result!.value),
                  const SizedBox(height: 8),
                  Text(_result!.detail),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            context.l10n.calcDisclaimer,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

enum _CalculatorKind {
  compoundInterest,
  loan,
  creditCardPayoff,
  savingsGoal,
  roi,
  currencyConverter,
  ruleOf72,
  inflation,
  salaryToHourly,
  taxEquivalentYield,
  irrNpv,
  tipPercentage,
}

class _CalculatorConfig {
  const _CalculatorConfig({
    required this.kind,
    required this.title,
    required this.icon,
    required this.color,
    required this.fields,
  });

  /// [id] is the calculator's stable English id (see the library list).
  factory _CalculatorConfig.fromId(String id, AppLocalizations l10n) {
    return switch (id) {
      'Loan' => _CalculatorConfig(
        kind: _CalculatorKind.loan,
        title: l10n.calcConfigLoanPayment,
        icon: Icons.payments_outlined,
        color: AikoColors.deepBlue,
        fields: [
          _CalculatorField(
            id: 'principal',
            label: l10n.calcFieldPrincipal,
            money: true,
          ),
          _CalculatorField(
            id: 'annualRate',
            label: l10n.calcFieldAnnualRate,
            suffixText: '%',
          ),
          _CalculatorField(
            id: 'months',
            label: l10n.calcFieldTermMonths,
            allowsDecimal: false,
          ),
        ],
      ),
      'Credit card payoff' => _CalculatorConfig(
        kind: _CalculatorKind.creditCardPayoff,
        title: l10n.calcConfigCreditCardPayoff,
        icon: Icons.credit_card_outlined,
        color: AikoColors.warningOrange,
        fields: [
          _CalculatorField(
            id: 'balance',
            label: l10n.calcFieldBalance,
            money: true,
          ),
          _CalculatorField(
            id: 'annualRate',
            label: l10n.calcFieldApr,
            suffixText: '%',
          ),
          _CalculatorField(
            id: 'monthlyPayment',
            label: l10n.calcFieldMonthlyPayment,
            money: true,
          ),
        ],
      ),
      'Savings goal' => _CalculatorConfig(
        kind: _CalculatorKind.savingsGoal,
        title: l10n.calcConfigSavingsGoal,
        icon: Icons.flag_outlined,
        color: AikoColors.successGreen,
        fields: [
          _CalculatorField(
            id: 'target',
            label: l10n.calcFieldTarget,
            money: true,
          ),
          _CalculatorField(
            id: 'startingBalance',
            label: l10n.calcFieldStartingBalance,
            money: true,
            initialValue: '0',
          ),
          _CalculatorField(
            id: 'monthlyContribution',
            label: l10n.calcFieldMonthlyContribution,
            money: true,
          ),
          _CalculatorField(
            id: 'annualRate',
            label: l10n.calcFieldAnnualGrowth,
            suffixText: '%',
            initialValue: '0',
          ),
        ],
      ),
      'ROI' => _CalculatorConfig(
        kind: _CalculatorKind.roi,
        title: l10n.calcConfigReturnOnInvestment,
        icon: Icons.show_chart,
        color: AikoColors.analyticsTeal,
        fields: [
          _CalculatorField(
            id: 'initialInvestment',
            label: l10n.calcFieldInitialInvestment,
            money: true,
          ),
          _CalculatorField(
            id: 'endingValue',
            label: l10n.calcFieldEndingValue,
            money: true,
          ),
          _CalculatorField(
            id: 'fees',
            label: l10n.calcFieldFees,
            money: true,
            initialValue: '0',
          ),
          _CalculatorField(
            id: 'income',
            label: l10n.calcFieldIncome,
            money: true,
            initialValue: '0',
          ),
        ],
      ),
      'Rule of 72' => _CalculatorConfig(
        kind: _CalculatorKind.ruleOf72,
        title: l10n.calcConfigRuleOf72,
        icon: Icons.timer_outlined,
        color: AikoColors.successGreen,
        fields: [
          _CalculatorField(
            id: 'annualRate',
            label: l10n.calcFieldAnnualRate,
            suffixText: '%',
            initialValue: '8',
          ),
        ],
      ),
      'Inflation' => _CalculatorConfig(
        kind: _CalculatorKind.inflation,
        title: l10n.calcConfigInflationAdjusted,
        icon: Icons.money_off_csred_outlined,
        color: AikoColors.dangerRed,
        fields: [
          _CalculatorField(
            id: 'amount',
            label: l10n.calcFieldCurrentAmount,
            money: true,
            initialValue: '1000',
          ),
          _CalculatorField(
            id: 'annualInflationRate',
            label: l10n.calcFieldAnnualInflation,
            suffixText: '%',
            initialValue: '3',
          ),
          _CalculatorField(
            id: 'years',
            label: l10n.calcFieldYears,
            allowsDecimal: false,
            initialValue: '10',
          ),
        ],
      ),
      'Salary to hourly' => _CalculatorConfig(
        kind: _CalculatorKind.salaryToHourly,
        title: l10n.calcConfigSalaryToHourly,
        icon: Icons.work_outline,
        color: AikoColors.deepBlue,
        fields: [
          _CalculatorField(
            id: 'annualSalary',
            label: l10n.calcFieldAnnualSalary,
            money: true,
            initialValue: '50000',
          ),
          _CalculatorField(
            id: 'hoursPerWeek',
            label: l10n.calcFieldHoursPerWeek,
            initialValue: '40',
          ),
          _CalculatorField(
            id: 'weeksPerYear',
            label: l10n.calcFieldWeeksPerYear,
            allowsDecimal: false,
            initialValue: '52',
          ),
        ],
      ),
      'Tax equivalent yield' => _CalculatorConfig(
        kind: _CalculatorKind.taxEquivalentYield,
        title: l10n.calcConfigTaxEquivalentYield,
        icon: Icons.account_balance_wallet_outlined,
        color: AikoColors.warningOrange,
        fields: [
          _CalculatorField(
            id: 'taxFreeYield',
            label: l10n.calcFieldTaxFreeYield,
            suffixText: '%',
            initialValue: '3.5',
          ),
          _CalculatorField(
            id: 'marginalTaxRate',
            label: l10n.calcFieldMarginalTaxRate,
            suffixText: '%',
            initialValue: '24',
          ),
        ],
      ),
      'IRR / NPV' => _CalculatorConfig(
        kind: _CalculatorKind.irrNpv,
        title: l10n.calcConfigNetPresentValue,
        icon: Icons.analytics_outlined,
        color: AikoColors.analyticsTeal,
        fields: [
          _CalculatorField(
            id: 'discountRate',
            label: l10n.calcFieldDiscountRate,
            suffixText: '%',
            initialValue: '8',
          ),
          _CalculatorField(
            id: 'cashFlows',
            label: l10n.calcFieldCashFlows,
            initialValue: '-1000, 300, 450, 600',
          ),
        ],
      ),
      'Tip and percentage' => _CalculatorConfig(
        kind: _CalculatorKind.tipPercentage,
        title: l10n.calcConfigTipSplit,
        icon: Icons.restaurant_outlined,
        color: AikoColors.successGreen,
        fields: [
          _CalculatorField(
            id: 'bill',
            label: l10n.calcFieldBillAmount,
            money: true,
            initialValue: '50',
          ),
          _CalculatorField(
            id: 'tipRate',
            label: l10n.calcFieldTipRate,
            suffixText: '%',
            initialValue: '15',
          ),
          _CalculatorField(
            id: 'splitCount',
            label: l10n.calcFieldSplitCount,
            allowsDecimal: false,
            initialValue: '1',
          ),
        ],
      ),
      'Currency converter' => _CalculatorConfig(
        kind: _CalculatorKind.currencyConverter,
        title: l10n.calcConfigCurrencyConverter,
        icon: Icons.currency_exchange,
        color: AikoColors.analyticsTeal,
        fields: [
          _CalculatorField(id: 'sourceAmount', label: l10n.calcFieldAmount),
          _CalculatorField(
            id: 'exchangeRate',
            label: l10n.calcFieldExchangeRate,
          ),
        ],
      ),
      _ => _CalculatorConfig(
        kind: _CalculatorKind.compoundInterest,
        title: l10n.calcConfigCompoundInterest,
        icon: Icons.trending_up,
        color: AikoColors.successGreen,
        fields: [
          _CalculatorField(
            id: 'principal',
            label: l10n.calcFieldPrincipal,
            money: true,
          ),
          _CalculatorField(
            id: 'monthlyContribution',
            label: l10n.calcFieldMonthlyContribution,
            money: true,
          ),
          _CalculatorField(
            id: 'annualRate',
            label: l10n.calcFieldAnnualRate,
            suffixText: '%',
          ),
          _CalculatorField(
            id: 'years',
            label: l10n.calcFieldYears,
            allowsDecimal: false,
          ),
        ],
      ),
    };
  }

  final _CalculatorKind kind;
  final String title;
  final IconData icon;
  final Color color;
  final List<_CalculatorField> fields;

  _CalculatorField fieldFor(String id) {
    return fields.singleWhere((field) => field.id == id);
  }
}

class _CalculatorField {
  const _CalculatorField({
    required this.id,
    required this.label,
    this.money = false,
    this.suffixText,
    this.initialValue = '',
    this.allowsDecimal = true,
  });

  final String id;
  final String label;

  /// An amount in the user's base currency; shows its symbol as a prefix.
  final bool money;
  final String? suffixText;
  final String initialValue;
  final bool allowsDecimal;
}

class _CalculationResult {
  const _CalculationResult({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
}

class _PayoffResult {
  const _PayoffResult({required this.months, required this.interest});

  final int months;
  final double interest;
}

class _CalculatorInputException implements Exception {
  const _CalculatorInputException(this.message);

  final String message;
}
