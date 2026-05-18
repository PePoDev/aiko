import 'package:flutter/material.dart';

class DashboardCustomizationSheet extends StatelessWidget {
  const DashboardCustomizationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SwitchListTile(
          value: true,
          onChanged: null,
          title: Text('Safe to spend'),
        ),
        SwitchListTile(value: true, onChanged: null, title: Text('Pace')),
        SwitchListTile(
          value: true,
          onChanged: null,
          title: Text('Recent transactions'),
        ),
      ],
    );
  }
}
