import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class AssetsNetWorthScreen extends StatelessWidget {
  const AssetsNetWorthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Assets and Net Worth',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.account_balance_outlined,
          title: 'Net worth',
          subtitle: 'Assets minus liabilities.',
          accentColor: AikoColors.analyticsTeal,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.donut_large_outlined,
          title: 'Asset allocation',
          subtitle: 'Cash, investments, property, and other assets.',
          accentColor: AikoColors.deepBlue,
        ),
      ],
    );
  }
}
