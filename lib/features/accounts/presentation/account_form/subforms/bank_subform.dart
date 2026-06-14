import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../domain/account_details.dart';
import 'account_subform.dart';

class BankSubform extends AccountSubform {
  const BankSubform({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final BankDetails initial;
  final ValueChanged<BankDetails> onChanged;

  @override
  ConsumerState<BankSubform> createState() => _BankSubformState();
}

class _BankSubformState extends AccountSubformState<BankSubform> {
  late final TextEditingController _last4;
  late final TextEditingController _holder;

  @override
  void initState() {
    super.initState();
    _last4 = TextEditingController(text: widget.initial.accountNumberLast4 ?? '');
    _holder = TextEditingController(text: widget.initial.accountHolderName ?? '');
    _last4.addListener(_emit);
    _holder.addListener(_emit);
  }

  void _emit() {
    widget.onChanged(BankDetails(
      accountNumberLast4:
          _last4.text.trim().isEmpty ? null : _last4.text.trim(),
      accountHolderName:
          _holder.text.trim().isEmpty ? null : _holder.text.trim(),
    ));
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! BankDetails) return;
    _last4.text = initial.accountNumberLast4 ?? '';
    _holder.text = initial.accountHolderName ?? '';
  }

  @override
  AccountDetails getDetails() => BankDetails(
        accountNumberLast4:
            _last4.text.trim().isEmpty ? null : _last4.text.trim(),
        accountHolderName:
            _holder.text.trim().isEmpty ? null : _holder.text.trim(),
      );

  @override
  String? validate() => null;

  @override
  void dispose() {
    _last4.dispose();
    _holder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _last4,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: 'Account number (last 4)',
            prefixIcon: Icon(Icons.numbers_outlined),
          ),
        ),
        TextField(
          controller: _holder,
          decoration: const InputDecoration(
            labelText: 'Account holder name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
      ],
    );
  }
}
