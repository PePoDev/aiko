import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Bills and Subscriptions',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.event_available_outlined,
          title: 'Upcoming bills',
          subtitle: 'Renewals and due dates appear with Aiko reminders.',
          accentColor: AikoColors.warningOrange,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.subscriptions_outlined,
          title: 'Subscription review',
          subtitle: 'Annualized costs and cancellation candidates.',
          accentColor: AikoColors.deepBlue,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.savings_outlined,
          title: 'Lower your bills',
          subtitle: 'Review price changes and savings opportunities.',
          accentColor: AikoColors.successGreen,
        ),
      ],
    );
  }
}
