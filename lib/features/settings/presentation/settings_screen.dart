import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(title: Text('Profile')),
          const ListTile(title: Text('Security')),
          const ListTile(title: Text('Currency')),
          const ListTile(title: Text('AI consent')),
          ListTile(
            title: const Text('Notifications'),
            onTap: () => context.go('/notification-settings'),
          ),
          ListTile(
            title: const Text('Import, export, and backup'),
            onTap: () => context.go('/import-export-backup'),
          ),
          ListTile(
            title: const Text('Subscription plan'),
            onTap: () => context.go('/subscription-plan'),
          ),
        ],
      ),
    );
  }
}
