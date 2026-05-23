import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/finance_card.dart';

class CalculatorShortcutsWidget extends StatelessWidget {
  const CalculatorShortcutsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      title: 'Calculator shortcuts',
      icon: Icons.calculate_outlined,
      child: Wrap(
        spacing: 8,
        children: [
          ActionChip(
            label: const Text('Savings goal'),
            onPressed: () => context.push('/calculators'),
          ),
          ActionChip(
            label: const Text('Loan'),
            onPressed: () => context.push('/calculators'),
          ),
          ActionChip(
            label: const Text('ROI'),
            onPressed: () => context.push('/calculators'),
          ),
        ],
      ),
    );
  }
}
