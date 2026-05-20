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
              'Choose date range and confirm sensitive financial data export before sharing the file.',
          accentColor: AikoColors.analyticsTeal,
        ),
      ],
    );
  }
}
