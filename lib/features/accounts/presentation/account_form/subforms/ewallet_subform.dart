import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'account_subform.dart';
import '../../../domain/account_details.dart';

class EWalletSubform extends AccountSubform {
  const EWalletSubform({super.key});

  @override
  ConsumerState<EWalletSubform> createState() => _EWalletSubformState();
}

class _EWalletSubformState extends AccountSubformState<EWalletSubform> {
  @override
  AccountDetails getDetails() => const EWalletDetails();

  @override
  void resetTo(AccountDetails _) {}

  @override
  String? validate() => null;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
