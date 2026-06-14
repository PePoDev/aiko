import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'account_subform.dart';

class CashSubform extends AccountSubform {
  const CashSubform({super.key});

  @override
  ConsumerState<CashSubform> createState() => _CashSubformState();
}

class _CashSubformState extends AccountSubformState<CashSubform>
    with NoOpSubformMixin {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
