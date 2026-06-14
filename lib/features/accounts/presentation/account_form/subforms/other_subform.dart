import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/widgets/aiko_data_widgets.dart';
import '../../../../../theme/aiko_colors.dart';
import '../../../domain/account_details.dart';
import 'account_subform.dart';

class OtherSubform extends AccountSubform {
  const OtherSubform({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final OtherDetails initial;
  final ValueChanged<OtherDetails> onChanged;

  @override
  ConsumerState<OtherSubform> createState() => _OtherSubformState();
}

class _OtherSubformState extends AccountSubformState<OtherSubform> {
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.initial.notes ?? '');
    _notes.addListener(_emit);
  }

  void _emit() {
    widget.onChanged(
      OtherDetails(
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! OtherDetails) return;
    _notes.text = initial.notes ?? '';
  }

  @override
  AccountDetails getDetails() => OtherDetails(
    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
  );

  @override
  String? validate() => null;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'What kind of account is this?',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 8),
        const AikoInlineNotice(
          title: 'No extra details',
          message: 'Other accounts are flexible. Add notes to help future-you.',
          icon: Icons.lightbulb_outline,
          accentColor: AikoColors.deepBlue,
        ),
      ],
    );
  }
}
