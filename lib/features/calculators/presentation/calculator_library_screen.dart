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
    'Time value of money',
    'IRR / NPV',
    'Certificate of deposit',
    'Bond yield',
    'Tax equivalent yield',
    'Rule of 72',
    'Bi-weekly mortgage payment',
    'Refinance savings',
    'Rent vs. buy',
    'Home affordability',
    'Rental property cash flow',
    'Traditional vs. Roth IRA',
    'Required minimum distributions',
    'Social Security estimate',
    'Annuity payout',
    'Auto loan vs. lease',
    'WACC',
    'Black-Scholes options',
    'CAPM',
    'Capital gains',
    'Salary to hourly',
    'Paycheck tax',
    'Inflation',
    'Tip and percentage',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculators')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          const TextField(
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search calculator',
            ),
          ),
          const SizedBox(height: 16),
          for (final calculator in calculators)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FinanceCard(
                title: calculator,
                icon: Icons.calculate_outlined,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CalculatorDetailScreen(title: calculator),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
