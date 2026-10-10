import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/finance_card.dart';
import 'calculator_form.dart';
import 'calculator_forms.dart';

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
  late CalculatorForm _form;
  late Map<String, TextEditingController> _controllers;
  late Map<String, String> _choices;
  CalculatorResult? _result;

  /// The result card, scrolled into view after Calculate.
  final _resultKey = GlobalKey();

  /// Unknown ids fall back to compound interest.
  CalculatorForm _formFor(AppLocalizations l10n) =>
      calculatorForm(widget.calculatorId, l10n) ??
      calculatorForm('Compound interest', l10n)!;

  @override
  void initState() {
    super.initState();
    _form = _formFor(currentL10n());
    _controllers = {
      for (final field in _form.fields)
        if (!field.isChoice)
          field.id: TextEditingController(text: field.initialValue),
    };
    _choices = {
      for (final field in _form.fields)
        if (field.isChoice) field.id: field.initialValue,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Same fields and ids; labels in the current language.
    _form = _formFor(context.l10n);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _values => {
    for (final entry in _controllers.entries) entry.key: entry.value.text,
    ..._choices,
  };

  String get _currency =>
      _form.currency ??
      ref.read(profileProvider).value?.baseCurrency ??
      kDefaultBaseCurrency;

  void _calculate() {
    final l10n = context.l10n;
    try {
      final result = _form.calculate(
        CalculatorInputs(
          form: _form,
          values: _values,
          l10n: l10n,
          currency: _currency,
        ),
      );
      setState(() => _result = result);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final resultContext = _resultKey.currentContext;
        if (resultContext == null || !resultContext.mounted) return;
        Scrollable.ensureVisible(
          resultContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } on CalculatorInputException catch (error) {
      _showError(error.message);
    } on ArgumentError catch (error) {
      _showError(calculatorErrorMessage(error, l10n));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The old result answered a different question.
  void _clearResult() {
    if (_result != null) setState(() => _result = null);
  }

  void _choose(String fieldId, String? value) {
    if (value == null) return;
    setState(() {
      _choices[fieldId] = value;
      // The old result answered a different question.
      _result = null;
    });
  }

  Widget _buildField(CalculatorField field, String currencySymbol) {
    if (field.isChoice) {
      return DropdownButtonFormField<String>(
        key: ValueKey(field.id),
        initialValue: _choices[field.id],
        isExpanded: true,
        decoration: InputDecoration(
          labelText: field.label,
          helperText: field.helper,
          helperMaxLines: 3,
        ),
        items: [
          for (final option in field.options)
            DropdownMenuItem(
              value: option.value,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) => _choose(field.id, value),
      );
    }
    return TextField(
      key: ValueKey(field.id),
      controller: _controllers[field.id],
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helper,
        helperMaxLines: 3,
        prefixText: field.money ? '$currencySymbol ' : null,
        suffixText: field.suffixText,
      ),
      onChanged: (_) => _clearResult(),
      keyboardType: field.text
          ? TextInputType.text
          : TextInputType.numberWithOptions(decimal: field.allowsDecimal),
      textInputAction: TextInputAction.next,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencySymbol = NumberFormat.simpleCurrency(
      name: _currency,
    ).currencySymbol;
    final values = _values;
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      // Not a lazy ListView: the result card must be built for
      // ensureVisible to find it, however far below the form it lands.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinanceCard(
              title: _form.title,
              icon: _form.icon,
              accentColor: _form.color,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final field in _form.fields)
                    if (_form.isVisible(field, values)) ...[
                      _buildField(field, currencySymbol),
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
            if (result != null) ...[
              const SizedBox(height: 16),
              FinanceCard(
                key: _resultKey,
                title: result.title,
                icon: result.icon,
                accentColor: result.color,
                prominent: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AmountText(result.value),
                    if (result.rows.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      for (final row in result.rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  row.label,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                row.value,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (result.detail case final detail?) ...[
                      const SizedBox(height: 8),
                      Text(detail),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(context.l10n.calcDisclaimer, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
