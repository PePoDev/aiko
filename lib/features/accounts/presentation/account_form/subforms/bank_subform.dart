import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'account_subform.dart';
import '../../../domain/account_details.dart';

class BankSubform extends AccountSubform {
  const BankSubform({super.key});

  @override
  ConsumerState<BankSubform> createState() => _BankSubformState();
}

class _BankSubformState extends AccountSubformState<BankSubform> {
  @override
  AccountDetails getDetails() => const BankDetails();

  @override
  void resetTo(AccountDetails _) {}

  @override
  String? validate() => null;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
