import 'package:flutter/material.dart';

import '../../../../../shared/widgets/aiko_data_widgets.dart';
import '../../../../../theme/aiko_colors.dart';
import '../../domain/account_details.dart';
import 'account_subform.dart';

class CashSubform extends AccountSubform {
  const CashSubform({super.key});

  @override
  State<CashSubform> createState() => _CashSubformState();
}

class _CashSubformState extends AccountSubformState<CashSubform>
    with NoOpSubformMixin {
  @override
  Widget build(BuildContext context) {
    return const AikoInlineNotice(
      title: 'No extra details',
      message: 'Cash accounts do not require additional setup.',
      icon: Icons.savings_outlined,
      accentColor: AikoColors.successGreen,
    );
  }
}
