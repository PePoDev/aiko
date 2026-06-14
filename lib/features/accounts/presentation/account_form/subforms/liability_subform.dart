import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../domain/account_details.dart';
import 'account_subform.dart';

class LiabilitySubform extends AccountSubform {
  const LiabilitySubform({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final LiabilityDetails initial;
  final ValueChanged<LiabilityDetails> onChanged;

  @override
  ConsumerState<LiabilitySubform> createState() => _LiabilitySubformState();
}

class _LiabilitySubformState extends AccountSubformState<LiabilitySubform> {
  late final TextEditingController _type;
  late final TextEditingController _apr;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _type = TextEditingController(text: widget.initial.liabilityType ?? '');
    _apr = TextEditingController(
      text: widget.initial.interestRatePercent?.toString() ?? '',
    );
    _notes = TextEditingController(text: widget.initial.notes ?? '');
    _type.addListener(_emit);
    _apr.addListener(_emit);
    _notes.addListener(_emit);
  }

  void _emit() {
    widget.onChanged(
      LiabilityDetails(
        liabilityType: _type.text.trim().isEmpty ? null : _type.text.trim(),
        interestRatePercent: double.tryParse(_apr.text.trim()),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! LiabilityDetails) return;
    _type.text = initial.liabilityType ?? '';
    _apr.text = initial.interestRatePercent?.toString() ?? '';
    _notes.text = initial.notes ?? '';
  }

  @override
  AccountDetails getDetails() => LiabilityDetails(
    liabilityType: _type.text.trim().isEmpty ? null : _type.text.trim(),
    interestRatePercent: double.tryParse(_apr.text.trim()),
    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
  );

  @override
  String? validate() {
    final apr = double.tryParse(_apr.text.trim());
    if (_apr.text.trim().isNotEmpty && apr == null) {
      return 'Enter a valid APR.';
    }
    return null;
  }

  @override
  void dispose() {
    _type.dispose();
    _apr.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _type,
          decoration: const InputDecoration(
            labelText: 'Type',
            hintText: 'e.g. Overdraft, Personal loan',
            prefixIcon: Icon(Icons.label_outline),
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
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
      ],
    );
  }
}
