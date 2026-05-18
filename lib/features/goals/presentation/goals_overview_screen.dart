import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_card.dart';

class GoalsOverviewScreen extends StatelessWidget {
  const GoalsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: FinanceCard(
        title: 'Emergency fund',
        icon: Icons.flag_outlined,
        child: LinearProgressIndicator(value: 0.62),
      ),
    );
  }
}
