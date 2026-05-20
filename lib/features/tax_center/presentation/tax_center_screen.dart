import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class TaxCenterScreen extends StatelessWidget {
  const TaxCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Tax Center',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.request_quote_outlined,
          title: 'Tax estimates',
          subtitle: 'Organize tax-year income and deductions.',
          accentColor: AikoColors.analyticsTeal,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.privacy_tip_outlined,
          title: 'Tax disclaimer',
          subtitle: 'Aiko tax outputs are estimates, not professional advice.',
          accentColor: AikoColors.warningOrange,
        ),
      ],
    );
  }
}
