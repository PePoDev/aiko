import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Portfolio',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.show_chart_outlined,
          title: 'Holdings',
          subtitle: 'Track value, gains, dividends, and fees.',
          accentColor: AikoColors.analyticsTeal,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.track_changes_outlined,
          title: 'Allocation drift',
          subtitle: 'Compare current holdings with target allocation.',
          accentColor: AikoColors.warningOrange,
        ),
      ],
    );
  }
}
