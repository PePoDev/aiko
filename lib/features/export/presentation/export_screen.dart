import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Export',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.file_download_outlined,
          title: 'Export CSV',
          subtitle:
              'Choose a date range and confirm sensitive financial data export before sharing.',
          accentColor: AikoColors.analyticsTeal,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.picture_as_pdf_outlined,
          title: 'PDF statements',
          subtitle:
              'Generate a styled HTML statement that can be printed or shared as PDF.',
          accentColor: AikoColors.dangerRed,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.table_chart_outlined,
          title: 'Excel export',
          subtitle:
              'Create Excel-compatible CSV with a UTF-8 BOM for spreadsheet apps.',
          accentColor: AikoColors.successGreen,
        ),
      ],
    );
  }
}
