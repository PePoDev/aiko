import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_card.dart';
import 'budget_form_screen.dart';

class BudgetOverviewScreen extends StatelessWidget {
  const BudgetOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          FinanceCard(
            title: 'Dining',
            icon: Icons.restaurant_outlined,
            child: LinearProgressIndicator(value: 0.78),
          ),
          SizedBox(height: 12),
          FinanceCard(
            title: 'Aiko recommendation',
            icon: Icons.auto_awesome,
            child: Text('Keep dining under 12 USD per day to stay on track.'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BudgetFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Budget'),
      ),
    );
  }
}
