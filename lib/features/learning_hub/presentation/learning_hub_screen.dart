import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class LearningHubScreen extends StatelessWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Learning Hub',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.school_outlined,
          title: 'Recommended lessons',
          subtitle: 'Aiko suggests personal finance topics.',
          accentColor: AikoColors.premiumPurple,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.quiz_outlined,
          title: 'Quizzes',
          subtitle: 'Track learning progress and scores.',
          accentColor: AikoColors.deepBlue,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.menu_book_outlined,
          title: 'Glossary',
          subtitle: 'Look up financial terms quickly.',
          accentColor: AikoColors.analyticsTeal,
        ),
      ],
    );
  }
}
