import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class AikoOptimizeScreen extends StatelessWidget {
  const AikoOptimizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Aiko Optimize',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.tune_outlined,
          title: 'Optimization suggestions',
          subtitle: 'Ranked, explainable next steps.',
          accentColor: AikoColors.premiumPurple,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.timeline_outlined,
          title: 'Prediction scenarios',
          subtitle: 'Expected range with freshness checks.',
          accentColor: AikoColors.analyticsTeal,
        ),
      ],
    );
  }
}
