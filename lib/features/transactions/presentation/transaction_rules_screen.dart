import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class TransactionRulesScreen extends StatelessWidget {
  const TransactionRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Transaction rules',
      bottomPadding: 32,
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.rule,
          title: 'If merchant contains Netflix',
          subtitle: 'Category: Subscriptions - Tag: Entertainment',
          accentColor: AikoColors.deepBlue,
        ),
      ],
    );
  }
}
