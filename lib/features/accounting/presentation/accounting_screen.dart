import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_overview_screen.dart';
import '../../../theme/aiko_colors.dart';

class AccountingScreen extends StatelessWidget {
  const AccountingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoFeatureOverviewScreen(
      title: 'Accounting',
      items: [
        AikoFeatureOverviewItem(
          icon: Icons.business_center_outlined,
          title: 'Business mode',
          subtitle: 'Separate personal and business records.',
          accentColor: AikoColors.neutralInk,
        ),
        AikoFeatureOverviewItem(
          icon: Icons.fact_check_outlined,
          title: 'Reconciliation',
          subtitle: 'Review pending accounting entries.',
          accentColor: AikoColors.analyticsTeal,
        ),
      ],
    );
  }
}
