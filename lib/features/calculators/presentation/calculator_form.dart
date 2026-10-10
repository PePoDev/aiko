import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';

/// One calculator: its inputs and how they become a result.
/// `CalculatorDetailScreen` renders any form; the forms live in
/// `calculator_forms.dart`.
class CalculatorForm {
  const CalculatorForm({
    required this.title,
    required this.icon,
    required this.color,
    required this.fields,
    required this.calculate,
    this.currency,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<CalculatorField> fields;

  /// Currency of money fields and results. Null uses the user's base
  /// currency; calculators built on Thai tax rules use baht.
  final String? currency;

  /// Throws [CalculatorInputException] for invalid input; may throw an
  /// [ArgumentError] from `CalculatorServices` (see [calculatorErrorMessage]).
  final CalculatorResult Function(CalculatorInputs inputs) calculate;

  CalculatorField fieldFor(String id) =>
      fields.singleWhere((field) => field.id == id);

  /// Whether [field] applies given the current choices.
  bool isVisible(CalculatorField field, Map<String, String> values) {
    final condition = field.showWhen;
    if (condition == null) return true;
    return condition.values.contains(values[condition.field]);
  }
}

class CalculatorField {
  const CalculatorField({
    required this.id,
    required this.label,
    this.money = false,
    this.suffixText,
    this.initialValue = '',
    this.allowsDecimal = true,
    this.text = false,
    this.helper,
    this.options = const [],
    this.showWhen,
  });

  final String id;
  final String label;

  /// An amount in the form's currency; shows its symbol as a prefix.
  final bool money;
  final String? suffixText;

  /// The starting text, or the selected option's value for a choice.
  final String initialValue;
  final bool allowsDecimal;

  /// Free text (a list of numbers) rather than a single number.
  final bool text;

  /// A hint shown under the field.
  final String? helper;

  /// Non-empty for a choice between [options] instead of a text field.
  final List<CalculatorOption> options;

  /// Shown only while the choice field [field] has one of [values].
  final ({String field, List<String> values})? showWhen;

  bool get isChoice => options.isNotEmpty;
}

class CalculatorOption {
  const CalculatorOption(this.value, this.label);

  final String value;
  final String label;
}

class CalculatorResult {
  const CalculatorResult({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.detail,
    this.rows = const [],
  });

  final String title;
  final String value;
  final String? detail;
  final IconData icon;
  final Color color;

  /// Supporting figures listed under the headline value.
  final List<({String label, String value})> rows;
}

class CalculatorInputException implements Exception {
  const CalculatorInputException(this.message);

  final String message;
}

/// Reads and validates a form's current values, and formats results.
class CalculatorInputs {
  CalculatorInputs({
    required this.form,
    required this.values,
    required this.l10n,
    required this.currency,
  });

  final CalculatorForm form;

  /// Field text, or the selected option's value, by field id.
  final Map<String, String> values;
  final AppLocalizations l10n;
  final String currency;

  String raw(String id) => values[id]?.trim() ?? '';

  String choice(String id) => values[id] ?? form.fieldFor(id).initialValue;

  /// A number above zero, or zero or above with [allowZero].
  double number(String id, {bool allowZero = false}) {
    final label = form.fieldFor(id).label;
    final value = double.tryParse(raw(id).replaceAll(',', ''));
    if (value == null) {
      throw CalculatorInputException(l10n.calcEnterValid(label));
    }
    if (allowZero ? value < 0 : value <= 0) {
      throw CalculatorInputException(l10n.calcMustBePositive(label));
    }
    return value;
  }

  int positiveInt(String id) {
    final value = int.tryParse(raw(id).replaceAll(',', ''));
    if (value == null || value <= 0) {
      throw CalculatorInputException(
        l10n.calcEnterValid(form.fieldFor(id).label),
      );
    }
    return value;
  }

  /// A percentage as a fraction (5 → 0.05). Zero is allowed unless
  /// [allowZero] is false; [atMost100] rejects over 100%.
  double percentage(
    String id, {
    bool allowZero = true,
    bool atMost100 = false,
  }) {
    final label = form.fieldFor(id).label;
    final value = double.tryParse(raw(id).replaceAll(',', ''));
    if (value == null || value < 0) {
      throw CalculatorInputException(l10n.calcEnterValid(label));
    }
    if (!allowZero && value == 0) {
      throw CalculatorInputException(l10n.calcMustBePositive(label));
    }
    if (atMost100 && value > 100) {
      throw CalculatorInputException(l10n.calcAtMost100(label));
    }
    return value / 100;
  }

  String money(double value) =>
      NumberFormat.simpleCurrency(name: currency).format(value);

  String percent(double value) =>
      NumberFormat.decimalPercentPattern(decimalDigits: 2).format(value);

  String decimal(double value) =>
      NumberFormat.decimalPatternDigits(decimalDigits: 2).format(value);

  /// A whole number of months as "2 yr 3 mo".
  String yearsMonths(int months) =>
      l10n.calcYearsMonthsValue(months ~/ 12, months % 12);
}

/// `CalculatorServices` validation errors in the user's language.
String calculatorErrorMessage(ArgumentError error, AppLocalizations l10n) {
  return switch ('${error.message}') {
    'Term must be positive.' => l10n.calcErrorTermPositive,
    'Initial investment must be positive.' => l10n.calcErrorInvestmentPositive,
    'Exchange rate must be positive.' => l10n.calcErrorRatePositive,
    'Annual rate must be positive.' => l10n.calcErrorAnnualRatePositive,
    'Marginal tax rate must be below 100%.' => l10n.calcErrorTaxRateBelow100,
    'Bond price is out of range.' => l10n.calcErrorBondPrice,
    'Capital must be positive.' => l10n.calcErrorCapitalPositive,
    _ => l10n.calcErrorGeneric,
  };
}
