import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class AikoReviewScreen extends StatelessWidget {
  const AikoReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Aiko Review',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.summarize_outlined,
          title: 'Aiko Review',
          subtitle:
              'Budget performance, goal progress, and next steps. Aiko guidance is an estimate and does not replace professional financial advice.',
          accentColor: AikoColors.premiumPurple,
        ),
      ],
    );
  }
}
