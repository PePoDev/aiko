import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_card.dart';
import 'calculator_detail_screen.dart';

class CalculatorLibraryScreen extends StatelessWidget {
  const CalculatorLibraryScreen({super.key});

  static const calculators = [
    'Compound interest',
    'Loan',
    'Credit card payoff',
    'Savings goal',
    'ROI',
    'Currency converter',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculators')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TextField(
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search calculator',
            ),
          ),
          const SizedBox(height: 12),
          for (final calculator in calculators)
            FinanceCard(
              title: calculator,
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CalculatorDetailScreen(title: calculator),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
        ],
      ),
    );
  }
}
