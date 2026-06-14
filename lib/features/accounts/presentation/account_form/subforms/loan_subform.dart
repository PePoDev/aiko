import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../../../core/money/money.dart';
import '../../../domain/account_details.dart';
import '../../../domain/account_validation_messages.dart';
import 'account_subform.dart';

class LoanSubform extends AccountSubform {
  const LoanSubform({
    super.key,
    required this.initial,
    required this.currency,
    required this.onChanged,
  });
  final LoanDetails initial;
  final String currency;
  final ValueChanged<LoanDetails> onChanged;

  @override
  ConsumerState<LoanSubform> createState() => _LoanSubformState();
}

class _LoanSubformState extends AccountSubformState<LoanSubform> {
  late LoanType _type;
  late final TextEditingController _principal;
  late final TextEditingController _apr;
  late final TextEditingController _term;
  late final TextEditingController _payment;
  late DateTime _due;

  @override
  void initState() {
    super.initState();
    _type = widget.initial.loanType;
    _principal = TextEditingController(
      text: widget.initial.principal.amount.toString(),
    );
    _apr = TextEditingController(
      text: widget.initial.interestRatePercent.toString(),
    );
    _term = TextEditingController(text: widget.initial.termMonths.toString());
    _payment = TextEditingController(
      text: widget.initial.monthlyPayment.amount.toString(),
    );
    _due = widget.initial.nextDueDate;
    for (final c in [_principal, _apr, _term, _payment]) {
      c.addListener(_emit);
    }
  }

  void _emit() {
    widget.onChanged(LoanDetails(
      loanType: _type,
      principal: _parseMoney(_principal.text),
      interestRatePercent: double.tryParse(_apr.text.trim()) ?? 0,
      termMonths: int.tryParse(_term.text.trim()) ?? 0,
      monthlyPayment: _parseMoney(_payment.text),
      nextDueDate: _due,
    ));
  }

  Money _parseMoney(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return Money.zero(widget.currency);
    try {
      return Money.parse(t, widget.currency);
    } catch (_) {
      return Money.zero(widget.currency);
    }
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! LoanDetails) return;
    setState(() {
      _type = initial.loanType;
      _principal.text = initial.principal.amount.toString();
      _apr.text = initial.interestRatePercent.toString();
      _term.text = initial.termMonths.toString();
      _payment.text = initial.monthlyPayment.amount.toString();
      _due = initial.nextDueDate;
    });
  }

  @override
  AccountDetails getDetails() => LoanDetails(
        loanType: _type,
        principal: _parseMoney(_principal.text),
        interestRatePercent: double.tryParse(_apr.text.trim()) ?? 0,
        termMonths: int.tryParse(_term.text.trim()) ?? 0,
        monthlyPayment: _parseMoney(_payment.text),
        nextDueDate: _due,
      );

  @override
  String? validate() {
    final term = int.tryParse(_term.text.trim()) ?? 0;
    if (term <= 0) return AccountValidationMessages.termMonthsPositive;
    return null;
  }

  @override
  void dispose() {
    _principal.dispose();
    _apr.dispose();
    _term.dispose();
    _payment.dispose();
    super.dispose();
  }

  String _dueLabel() {
    return '${_due.year}-${_due.month.toString().padLeft(2, '0')}-${_due.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<LoanType>(
          initialValue: _type,
          decoration: const InputDecoration(
            labelText: 'Loan type',
            prefixIcon: Icon(Icons.handshake_outlined),
          ),
          items: LoanType.values
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.name),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _type = v);
              _emit();
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _principal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Principal',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Interest rate (%)',
            prefixIcon: Icon(Icons.percent_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _term,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Term (months)',
            prefixIcon: Icon(Icons.calendar_view_month_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _payment,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monthly payment',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
              initialDate: _due,
            );
            if (picked != null) {
              setState(() => _due = picked);
              _emit();
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Next due date',
              prefixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(_dueLabel()),
          ),
        ),
      ],
    );
  }
}
