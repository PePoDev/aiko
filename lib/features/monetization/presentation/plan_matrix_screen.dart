import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class PlanMatrixScreen extends StatelessWidget {
  const PlanMatrixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Subscription Plan',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.spa_outlined,
          title: 'Free',
          subtitle: 'Manual tracking and basic insights.',
          accentColor: AikoColors.deepBlue,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.auto_awesome_outlined,
          title: 'Premium',
          subtitle: 'Forecasting, reports, sync, and advanced insights.',
          accentColor: AikoColors.premiumPurple,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.business_center_outlined,
          title: 'Pro',
          subtitle: 'Accounting, tax, business, and advanced planning.',
          accentColor: AikoColors.neutralInk,
        ),
      ],
    );
  }
}
