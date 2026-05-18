import 'package:flutter/material.dart';

class SavingPlanScreen extends StatelessWidget {
  const SavingPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.savings_outlined),
      title: Text('Weekly saving schedule'),
      subtitle: Text('Save 80 USD weekly to reach your goal.'),
    );
  }
}
