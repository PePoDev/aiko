import 'package:flutter/material.dart';

import '../../../../shared/widgets/screen_states.dart';

class DashboardEmptyState extends StatelessWidget {
  const DashboardEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const AikoScreenState.empty(
      title: 'Add your first transaction',
      message:
          'Aiko can calculate your dashboard after you add money movement.',
    );
  }
}
