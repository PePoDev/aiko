import 'package:flutter/material.dart';

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
        children: [
          SwitchListTile(
            value: _billReminders,
            onChanged: (value) => setState(() => _billReminders = value),
            title: const Text('Bill reminders'),
          ),
          SwitchListTile(
            value: _budgetAlerts,
            onChanged: (value) => setState(() => _budgetAlerts = value),
            title: const Text('Budget alerts'),
          ),
        ],
      ),
    );
  }
}
