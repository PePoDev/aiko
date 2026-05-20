import 'package:flutter/material.dart';

import '../../theme/aiko_colors.dart';
import 'finance_card.dart';

class AikoFeatureOverviewScreen extends StatelessWidget {
  const AikoFeatureOverviewScreen({
    required this.title,
    required this.items,
    this.bottomPadding = 112,
    super.key,
  });

  final String title;
  final List<AikoFeatureOverviewItem> items;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];

          return FinanceCard(
            title: item.title,
            icon: item.icon,
            accentColor: item.accentColor,
            child: Text(item.subtitle),
          );
        },
      ),
    );
  }
}

class AikoFeatureOverviewItem {
  const AikoFeatureOverviewItem({
    required this.title,
    required this.subtitle,
    this.icon = Icons.auto_awesome_outlined,
    this.accentColor = AikoColors.primaryBlue,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
}
