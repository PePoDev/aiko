import 'package:flutter/material.dart';

class DebtPayoffPlanScreen extends StatelessWidget {
  const DebtPayoffPlanScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Debt and Loans')),
    body: ListView(
      padding: EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: Icon(Icons.timeline_outlined),
          title: Text('Payoff strategies'),
          subtitle: Text(
            'Compare snowball, avalanche, and custom payoff plans.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.savings_outlined),
          title: Text('Interest savings'),
          subtitle: Text('Estimate months to payoff and priority order.'),
        ),
      ],
    ),
  );
}
