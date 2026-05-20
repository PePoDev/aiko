import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class CreditCardOverviewScreen extends StatelessWidget {
  const CreditCardOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Credit Cards',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.credit_card_outlined,
          title: 'Utilization',
          subtitle: 'Track limits, balances, APR, rewards, and due dates.',
          accentColor: AikoColors.deepBlue,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.payments_outlined,
          title: 'Payment planning',
          subtitle: 'Review minimum payment and interest estimates.',
          accentColor: AikoColors.warningOrange,
        ),
      ],
    );
  }
}
