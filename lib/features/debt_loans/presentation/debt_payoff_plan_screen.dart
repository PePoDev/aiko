import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class DebtPayoffPlanScreen extends StatelessWidget {
  const DebtPayoffPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Debt and Loans',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.timeline_outlined,
          title: 'Payoff strategies',
          subtitle: 'Compare snowball, avalanche, and custom payoff plans.',
          accentColor: AikoColors.deepBlue,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.savings_outlined,
          title: 'Interest savings',
          subtitle: 'Estimate months to payoff and priority order.',
          accentColor: AikoColors.successGreen,
        ),
      ],
    );
  }
}
