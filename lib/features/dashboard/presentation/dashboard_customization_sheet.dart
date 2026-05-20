import 'package:flutter/material.dart';

class DashboardCustomizationSheet extends StatelessWidget {
  const DashboardCustomizationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) => SwitchListTile(
        value: true,
        onChanged: null,
        title: Text(_items[index]),
      ),
    );
  }

  static const _items = ['Safe to spend', 'Pace', 'Recent transactions'];
}
