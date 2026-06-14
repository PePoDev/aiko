import 'package:flutter/material.dart';

import '../../domain/account_details.dart';
import 'account_subform.dart';

class InvestmentSubform extends AccountSubform {
  const InvestmentSubform({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final InvestmentDetails initial;
  final ValueChanged<InvestmentDetails> onChanged;

  @override
  State<InvestmentSubform> createState() => _InvestmentSubformState();
}

class _InvestmentSubformState extends AccountSubformState<InvestmentSubform> {
  late final TextEditingController _last4;
  @override
  void initState() {
    super.initState();
    _last4 =
        TextEditingController(text: widget.initial.accountNumberLast4 ?? '');
    _last4.addListener(_emit);
  }

  void _emit() {
    widget.onChanged(InvestmentDetails(
      accountNumberLast4:
          _last4.text.trim().isEmpty ? null : _last4.text.trim(),
    ));
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! InvestmentDetails) return;
    _last4.text = initial.accountNumberLast4 ?? '';
  }

  @override
  AccountDetails getDetails() => InvestmentDetails(
        accountNumberLast4:
            _last4.text.trim().isEmpty ? null : _last4.text.trim(),
      );

  @override
  String? validate() => null;

  @override
  void dispose() {
    _last4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _last4,
      maxLength: 4,
      decoration: const InputDecoration(
        labelText: 'Account number (last 4)',
        prefixIcon: Icon(Icons.numbers_outlined),
      ),
    );
  }
}
