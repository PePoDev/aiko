import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/finance_card.dart';

class AikoAssistantScreen extends StatelessWidget {
  const AikoAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aiko')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FinanceCard(
            title: 'Ask Aiko',
            icon: Icons.auto_awesome,
            child: Text(
              'You have 245 USD safe to spend this week. This is an estimate based on your Aiko data.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'Ask about your money',
              suffixIcon: IconButton(
                tooltip: 'Send question',
                onPressed: () {},
                icon: const Icon(Icons.send),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.go('/calculators'),
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Open calculators'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.go('/learning-hub'),
            icon: const Icon(Icons.school_outlined),
            label: const Text('Open Learning Hub'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.go('/aiko-optimize'),
            icon: const Icon(Icons.tune_outlined),
            label: const Text('Open Aiko Optimize'),
          ),
        ],
      ),
    );
  }
}
