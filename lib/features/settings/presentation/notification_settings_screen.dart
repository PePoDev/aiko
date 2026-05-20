import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _billReminders = true;
  bool _budgetAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          FinanceCard(
            title: 'Money alerts',
            icon: Icons.notifications_outlined,
            accentColor: AikoColors.warningOrange,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _billReminders,
                  onChanged: (value) => setState(() => _billReminders = value),
                  title: const Text('Bill reminders'),
                  subtitle: const Text('Upcoming due dates and renewals.'),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _budgetAlerts,
                  onChanged: (value) => setState(() => _budgetAlerts = value),
                  title: const Text('Budget alerts'),
                  subtitle: const Text('Progress, thresholds, and pacing.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
