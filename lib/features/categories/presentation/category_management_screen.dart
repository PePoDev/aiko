import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Categories',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.category_outlined,
          title: 'Food and Dining',
          subtitle: 'Needs - Budget enabled',
          accentColor: AikoColors.warningOrange,
        ),
      ],
    );
  }
}
