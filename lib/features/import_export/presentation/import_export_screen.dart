import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class ImportExportScreen extends StatelessWidget {
  const ImportExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Import, Export, and Backup',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.upload_file_outlined,
          title: 'Preview import',
          subtitle: 'Validate mappings, missing fields, and duplicates.',
          accentColor: AikoColors.deepBlue,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.file_download_outlined,
          title: 'Export package',
          subtitle: 'Choose scope and acknowledge sensitive data.',
          accentColor: AikoColors.analyticsTeal,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.cloud_sync_outlined,
          title: 'Backup status',
          subtitle: 'Review snapshots before restore.',
          accentColor: AikoColors.premiumPurple,
        ),
      ],
    );
  }
}
