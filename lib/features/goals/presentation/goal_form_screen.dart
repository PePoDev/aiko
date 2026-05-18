import 'package:flutter/material.dart';

class GoalFormScreen extends StatelessWidget {
  const GoalFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        TextField(decoration: InputDecoration(labelText: 'Goal name')),
        SizedBox(height: 12),
        TextField(decoration: InputDecoration(labelText: 'Target amount')),
      ],
    );
  }
}
