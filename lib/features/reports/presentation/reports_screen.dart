import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AikoFeatureOverviewScreen(
      title: 'Reports',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Monthly financial report',
          subtitle: 'Includes period, filters, and export metadata.',
          accentColor: AikoColors.deepBlue,
          onTap: () => context.push('/reports/monthly'),
        ),
      ],
    );
  }
}
