import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class TravelModeScreen extends StatelessWidget {
  const TravelModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Travel Mode',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.flight_takeoff_outlined,
          title: 'Trip budget',
          subtitle: 'Track local and home currency views.',
          accentColor: AikoColors.analyticsTeal,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.currency_exchange_outlined,
          title: 'Foreign fees',
          subtitle: 'Monitor exchange and card fee costs.',
          accentColor: AikoColors.warningOrange,
        ),
      ],
    );
  }
}
