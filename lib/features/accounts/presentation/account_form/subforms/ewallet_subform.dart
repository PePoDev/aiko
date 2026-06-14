import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../domain/account_details.dart';
import 'account_subform.dart';

class EWalletSubform extends AccountSubform {
  const EWalletSubform({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final EWalletDetails initial;
  final ValueChanged<EWalletDetails> onChanged;

  @override
  ConsumerState<EWalletSubform> createState() => _EWalletSubformState();
}

class _EWalletSubformState extends AccountSubformState<EWalletSubform> {
  late final TextEditingController _contact;
  @override
  void initState() {
    super.initState();
    _contact =
        TextEditingController(text: widget.initial.linkedPhoneOrEmail ?? '');
    _contact.addListener(_emit);
  }

  void _emit() {
    widget.onChanged(EWalletDetails(
      linkedPhoneOrEmail:
          _contact.text.trim().isEmpty ? null : _contact.text.trim(),
    ));
  }

  @override
  void resetTo(AccountDetails initial) {
    if (initial is! EWalletDetails) return;
    _contact.text = initial.linkedPhoneOrEmail ?? '';
  }

  @override
  AccountDetails getDetails() => EWalletDetails(
        linkedPhoneOrEmail:
            _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      );

  @override
  String? validate() => null;

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _contact,
      decoration: const InputDecoration(
        labelText: 'Linked phone or email',
        prefixIcon: Icon(Icons.alternate_email_outlined),
      ),
    );
  }
}
