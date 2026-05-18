import 'package:flutter/material.dart';

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
          const ListTile(title: Text('Export data')),
        ],
      ),
    );
  }
}
