import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Devices',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.devices_outlined,
          title: 'Trusted devices',
          subtitle: 'Manage sessions and remote sign-out.',
          accentColor: AikoColors.deepBlue,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.sync_problem_outlined,
          title: 'Sync conflicts',
          subtitle: 'Review conflicts before overwriting data.',
          accentColor: AikoColors.warningOrange,
        ),
      ],
    );
  }
}
