import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/calculator_services.dart';

class CalculatorDetailScreen extends StatefulWidget {
  const CalculatorDetailScreen({required this.title, super.key});

  final String title;

  @override
  State<CalculatorDetailScreen> createState() => _CalculatorDetailScreenState();
}

class _CalculatorDetailScreenState extends State<CalculatorDetailScreen> {
  static const _service = CalculatorServices();

  late _CalculatorConfig _config;
  late Map<String, TextEditingController> _controllers;
  _CalculationResult? _result;

  @override
  void initState() {
    super.initState();
    _config = _CalculatorConfig.fromTitle(widget.title);
    _controllers = {
      for (final field in _config.fields)
        field.id: TextEditingController(text: field.initialValue),
    };
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  _CalculationResult _compoundInterest() {
    final principal = _positiveNumber('principal');
    final monthlyContribution = _number('monthlyContribution', allowZero: true);
    final annualRate = _percentage('annualRate');
    final years = _positiveInt('years');

    final futureValue = _service.compoundInterest(
      principal: principal,
      monthlyContribution: monthlyContribution,
      annualRate: annualRate,
      years: years,
    );

    return _CalculationResult(
      title: 'Future value',
      value: _formatCurrency(futureValue),
      detail: 'Includes monthly contributions over $years years.',
      icon: Icons.trending_up,
      color: AikoColors.successGreen,
    );
  }

  _CalculationResult _loanPayment() {
    final principal = _positiveNumber('principal');
    final annualRate = _percentage('annualRate');
    final months = _positiveInt('months');

    final payment = _service.loanPayment(
      principal: principal,
      annualRate: annualRate,
      months: months,
    );
    final total = payment * months;

    return _CalculationResult(
      title: 'Monthly payment',
      value: _formatCurrency(payment),
      detail:
          'Estimated total paid ${_formatCurrency(total)} with ${_formatCurrency(total - principal)} in interest.',
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
      title: 'Payoff estimate',
      value: '${payoff.months} months',
      detail:
          'Estimated interest ${_formatCurrency(payoff.interest)} with a ${_formatCurrency(monthlyPayment)} monthly payment.',
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
      title: 'Goal timeline',
      value: months == 0 ? 'Already funded' : '$months months',
      detail:
          'Estimated with ${_formatCurrency(monthlyContribution)} saved each month.',
      icon: Icons.flag_outlined,
      color: AikoColors.successGreen,
    );
  }

  _CalculationResult _roi() {
    final initialInvestment = _positiveNumber('initialInvestment');
    final endingValue = _positiveNumber('endingValue');
    final fees = _number('fees', allowZero: true);
    final income = _number('income', allowZero: true);

    final roi = _service.roi(
      initialInvestment: initialInvestment,
      endingValue: endingValue,
      fees: fees,
      income: income,
    );
    final gain = endingValue + income - fees - initialInvestment;

    return _CalculationResult(
      title: 'Return on investment',
      value: _formatPercent(roi),
      detail: 'Net gain is ${_formatCurrency(gain)} after fees and income.',
      icon: Icons.show_chart,
      color: AikoColors.analyticsTeal,
    );
  }

  _CalculationResult _currencyConverter() {
    final sourceAmount = _positiveNumber('sourceAmount');
    final exchangeRate = _positiveNumber('exchangeRate');
    final converted = _service.convertCurrency(
      sourceAmount: sourceAmount,
      exchangeRate: exchangeRate,
    );

    return _CalculationResult(
      title: 'Converted amount',
      value: _formatNumber(converted),
      detail: 'Using exchange rate ${_formatNumber(exchangeRate)}.',
      icon: Icons.currency_exchange,
      color: AikoColors.analyticsTeal,
    );
  }

  _CalculationResult _ruleOf72() {
    final annualRate = _percentage('annualRate');
    final years = _service.ruleOf72(annualRate: annualRate);

    return _CalculationResult(
      title: 'Years to double',
      value: '${_formatNumber(years)} years',
      detail: 'Estimated time to double your investment at a constant ${_controllers['annualRate']!.text}% annual rate.',
      icon: Icons.timer_outlined,
      color: AikoColors.successGreen,
    );
  }

  _CalculationResult _inflation() {
    final amount = _positiveNumber('amount');
    final annualInflationRate = _percentage('annualInflationRate');
    final years = _positiveInt('years');

    final adjusted = _service.inflationAdjustedValue(
      amount: amount,
      annualInflationRate: annualInflationRate,
      years: years,
    );

    return _CalculationResult(
      title: 'Inflation-adjusted value',
      value: _formatCurrency(adjusted),
      detail: 'Purchasing power of ${_formatCurrency(amount)} in $years years at a constant ${_controllers['annualInflationRate']!.text}% inflation.',
      icon: Icons.money_off_csred_outlined,
      color: AikoColors.dangerRed,
    );
  }

  _CalculationResult _salaryToHourly() {
    final annualSalary = _positiveNumber('annualSalary');
    final hoursPerWeek = _positiveNumber('hoursPerWeek');
    final weeksPerYear = _positiveInt('weeksPerYear');

    final hourly = _service.salaryToHourly(
      annualSalary: annualSalary,
      hoursPerWeek: hoursPerWeek,
      weeksPerYear: weeksPerYear.toDouble(),
    );

    return _CalculationResult(
      title: 'Equivalent hourly pay',
      value: '${_formatCurrency(hourly)}/hr',
      detail: 'Based on working $hoursPerWeek hours per week for $weeksPerYear weeks per year.',
      icon: Icons.work_outline,
      color: AikoColors.deepBlue,
    );
  }

  _CalculationResult _taxEquivalentYield() {
    final taxFreeYield = _percentage('taxFreeYield');
    final marginalTaxRate = _percentage('marginalTaxRate');

    final equivalent = _service.taxEquivalentYield(
      taxFreeYield: taxFreeYield,
      marginalTaxRate: marginalTaxRate,
    );

    return _CalculationResult(
      title: 'Tax-equivalent yield',
      value: _formatPercent(equivalent),
      detail: 'Pre-tax return needed to equal a tax-free yield of ${_controllers['taxFreeYield']!.text}% at a ${_controllers['marginalTaxRate']!.text}% marginal tax bracket.',
      icon: Icons.account_balance_wallet_outlined,
      color: AikoColors.warningOrange,
    );
  }

  _CalculationResult _irrNpv() {
    final discountRate = _percentage('discountRate');
    final cashFlowsText = _controllers['cashFlows']!.text.trim();
    if (cashFlowsText.isEmpty) {
      throw const _CalculatorInputException('Enter a valid list of cash flows.');
    }
    final List<double> cashFlows;
    try {
      cashFlows = cashFlowsText.split(',').map((s) => double.parse(s.trim())).toList();
    } catch (_) {
      throw const _CalculatorInputException('Cash flows must be a list of numbers separated by commas.');
    }

    final npv = _service.netPresentValue(
      discountRate: discountRate,
      cashFlows: cashFlows,
    );

    return _CalculationResult(
      title: 'Net present value (NPV)',
      value: _formatCurrency(npv),
      detail: 'NPV of cash flows discounted at ${_controllers['discountRate']!.text}% per period.',
      icon: Icons.analytics_outlined,
      color: AikoColors.analyticsTeal,
    );
  }

  _CalculationResult _tipPercentage() {
    final bill = _positiveNumber('bill');
    final tipRate = _percentage('tipRate');
    final splitCount = _positiveInt('splitCount');

    final tip = _service.tipAmount(bill: bill, tipRate: tipRate);
    final total = bill + tip;
    final perPerson = total / splitCount;

    return _CalculationResult(
      title: 'Total split summary',
      value: '${_formatCurrency(perPerson)} each',
      detail: 'Tip is ${_formatCurrency(tip)} (total ${_formatCurrency(total)}) split between $splitCount people.',
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
      throw _CalculatorInputException('Enter a valid ${field.label}.');
    }
    if (allowZero ? value < 0 : value <= 0) {
      throw _CalculatorInputException('${field.label} must be positive.');
    }
    return value;
  }

  int _positiveInt(String id) {
    final field = _config.fieldFor(id);
    final value = int.tryParse(_controllers[id]!.text.trim());
    if (value == null || value <= 0) {
      throw _CalculatorInputException('Enter a valid ${field.label}.');
    }
    return value;
  }

  double _percentage(String id) {
    final field = _config.fieldFor(id);
    final value = double.tryParse(
      _controllers[id]!.text.trim().replaceAll(',', ''),
    );
    if (value == null || value < 0) {
      throw _CalculatorInputException('Enter a valid ${field.label}.');
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
        throw _CalculatorInputException(
          'Monthly payment is too low to reduce this balance.',
        );
      }
      interestPaid += interest;
      remaining = remaining + interest - monthlyPayment;
      months++;
    }

    if (months >= 1200) {
      throw _CalculatorInputException(
        'This payoff takes over 100 years. Try a higher payment.',
      );
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
      throw _CalculatorInputException(
        'This goal takes over 100 years. Try a higher monthly contribution.',
      );
    }

    return months;
  }

  String _formatCurrency(double value) {
    return NumberFormat.simpleCurrency(name: 'USD').format(value);
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
                      prefixText: field.prefixText,
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
                  label: const Text('Calculate'),
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
            'Results are estimates, not guarantees.',
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

  factory _CalculatorConfig.fromTitle(String title) {
    return switch (title) {
      'Loan' => const _CalculatorConfig(
        kind: _CalculatorKind.loan,
        title: 'Loan payment',
        icon: Icons.payments_outlined,
        color: AikoColors.deepBlue,
        fields: [
          _CalculatorField(
            id: 'principal',
            label: 'Principal',
            prefixText: r'$ ',
          ),
          _CalculatorField(
            id: 'annualRate',
            label: 'Annual rate',
            suffixText: '%',
          ),
          _CalculatorField(
            id: 'months',
            label: 'Term in months',
            allowsDecimal: false,
          ),
        ],
      ),
      'Credit card payoff' => const _CalculatorConfig(
        kind: _CalculatorKind.creditCardPayoff,
        title: 'Credit card payoff',
        icon: Icons.credit_card_outlined,
        color: AikoColors.warningOrange,
        fields: [
          _CalculatorField(id: 'balance', label: 'Balance', prefixText: r'$ '),
          _CalculatorField(id: 'annualRate', label: 'APR', suffixText: '%'),
          _CalculatorField(
            id: 'monthlyPayment',
            label: 'Monthly payment',
            prefixText: r'$ ',
          ),
        ],
      ),
      'Savings goal' => const _CalculatorConfig(
        kind: _CalculatorKind.savingsGoal,
        title: 'Savings goal',
        icon: Icons.flag_outlined,
        color: AikoColors.successGreen,
        fields: [
          _CalculatorField(id: 'target', label: 'Target', prefixText: r'$ '),
          _CalculatorField(
            id: 'startingBalance',
            label: 'Starting balance',
            prefixText: r'$ ',
            initialValue: '0',
          ),
          _CalculatorField(
            id: 'monthlyContribution',
            label: 'Monthly contribution',
            prefixText: r'$ ',
          ),
          _CalculatorField(
            id: 'annualRate',
            label: 'Annual growth',
            suffixText: '%',
            initialValue: '0',
          ),
        ],
      ),
      'ROI' => const _CalculatorConfig(
        kind: _CalculatorKind.roi,
        title: 'Return on investment',
        icon: Icons.show_chart,
        color: AikoColors.analyticsTeal,
        fields: [
          _CalculatorField(
            id: 'initialInvestment',
            label: 'Initial investment',
            prefixText: r'$ ',
          ),
          _CalculatorField(
            id: 'endingValue',
            label: 'Ending value',
            prefixText: r'$ ',
          ),
          _CalculatorField(
            id: 'fees',
            label: 'Fees',
            prefixText: r'$ ',
            initialValue: '0',
          ),
          _CalculatorField(
            id: 'income',
            label: 'Income',
            prefixText: r'$ ',
            initialValue: '0',
          ),
        ],
      ),
      'Rule of 72' => const _CalculatorConfig(
        kind: _CalculatorKind.ruleOf72,
        title: 'Rule of 72',
        icon: Icons.timer_outlined,
        color: AikoColors.successGreen,
        fields: [
          _CalculatorField(
            id: 'annualRate',
            label: 'Annual rate',
            suffixText: '%',
            initialValue: '8',
          ),
        ],
      ),
      'Inflation' => const _CalculatorConfig(
        kind: _CalculatorKind.inflation,
        title: 'Inflation adjusted value',
        icon: Icons.money_off_csred_outlined,
        color: AikoColors.dangerRed,
        fields: [
          _CalculatorField(
            id: 'amount',
            label: 'Current amount',
            prefixText: r'$ ',
            initialValue: '1000',
          ),
          _CalculatorField(
            id: 'annualInflationRate',
            label: 'Annual inflation rate',
            suffixText: '%',
            initialValue: '3',
          ),
          _CalculatorField(
            id: 'years',
            label: 'Years',
            allowsDecimal: false,
            initialValue: '10',
          ),
        ],
      ),
      'Salary to hourly' => const _CalculatorConfig(
        kind: _CalculatorKind.salaryToHourly,
        title: 'Salary to hourly',
        icon: Icons.work_outline,
        color: AikoColors.deepBlue,
        fields: [
          _CalculatorField(
            id: 'annualSalary',
            label: 'Annual salary',
            prefixText: r'$ ',
            initialValue: '50000',
          ),
          _CalculatorField(
            id: 'hoursPerWeek',
            label: 'Hours per week',
            initialValue: '40',
          ),
          _CalculatorField(
            id: 'weeksPerYear',
            label: 'Weeks per year',
            allowsDecimal: false,
            initialValue: '52',
          ),
        ],
      ),
      'Tax equivalent yield' => const _CalculatorConfig(
        kind: _CalculatorKind.taxEquivalentYield,
        title: 'Tax equivalent yield',
        icon: Icons.account_balance_wallet_outlined,
        color: AikoColors.warningOrange,
        fields: [
          _CalculatorField(
            id: 'taxFreeYield',
            label: 'Tax-free yield',
            suffixText: '%',
            initialValue: '3.5',
          ),
          _CalculatorField(
            id: 'marginalTaxRate',
            label: 'Marginal tax rate',
            suffixText: '%',
            initialValue: '24',
          ),
        ],
      ),
      'IRR / NPV' => const _CalculatorConfig(
        kind: _CalculatorKind.irrNpv,
        title: 'Net present value',
        icon: Icons.analytics_outlined,
        color: AikoColors.analyticsTeal,
        fields: [
          _CalculatorField(
            id: 'discountRate',
            label: 'Discount rate (Annual)',
            suffixText: '%',
            initialValue: '8',
          ),
          _CalculatorField(
            id: 'cashFlows',
            label: 'Cash flows (comma-separated, e.g. -1000, 300, 450, 600)',
            initialValue: '-1000, 300, 450, 600',
          ),
        ],
      ),
      'Tip and percentage' => const _CalculatorConfig(
        kind: _CalculatorKind.tipPercentage,
        title: 'Tip and split bill',
        icon: Icons.restaurant_outlined,
        color: AikoColors.successGreen,
        fields: [
          _CalculatorField(
            id: 'bill',
            label: 'Bill amount',
            prefixText: r'$ ',
            initialValue: '50',
          ),
          _CalculatorField(
            id: 'tipRate',
            label: 'Tip rate',
            suffixText: '%',
            initialValue: '15',
          ),
          _CalculatorField(
            id: 'splitCount',
            label: 'Split between (people)',
            allowsDecimal: false,
            initialValue: '1',
          ),
        ],
      ),
      'Currency converter' => const _CalculatorConfig(
        kind: _CalculatorKind.currencyConverter,
        title: 'Currency converter',
        icon: Icons.currency_exchange,
        color: AikoColors.analyticsTeal,
        fields: [
          _CalculatorField(id: 'sourceAmount', label: 'Amount'),
          _CalculatorField(id: 'exchangeRate', label: 'Exchange rate'),
        ],
      ),
      _ => const _CalculatorConfig(
        kind: _CalculatorKind.compoundInterest,
        title: 'Compound interest',
        icon: Icons.trending_up,
        color: AikoColors.successGreen,
        fields: [
          _CalculatorField(
            id: 'principal',
            label: 'Principal',
            prefixText: r'$ ',
          ),
          _CalculatorField(
            id: 'monthlyContribution',
            label: 'Monthly contribution',
            prefixText: r'$ ',
          ),
          _CalculatorField(
            id: 'annualRate',
            label: 'Annual rate',
            suffixText: '%',
          ),
          _CalculatorField(id: 'years', label: 'Years', allowsDecimal: false),
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
    this.prefixText,
    this.suffixText,
    this.initialValue = '',
    this.allowsDecimal = true,
  });

  final String id;
  final String label;
  final String? prefixText;
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
