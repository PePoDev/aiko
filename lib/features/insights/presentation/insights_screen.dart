import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/finance_card.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FinanceCard(
            title: 'Food spending increased',
            icon: Icons.insights,
            child: Text(
              'Food spending increased by 18%. Most of the increase came from weekend dining.',
            ),
          ),
          const SizedBox(height: 12),
          FinanceCard(
            title: 'Aiko Review',
            icon: Icons.summarize_outlined,
            child: FilledButton(
              onPressed: () => context.go('/aiko-review'),
              child: const Text('Open monthly review'),
            ),
          ),
        ],
      ),
    );
  }
}
