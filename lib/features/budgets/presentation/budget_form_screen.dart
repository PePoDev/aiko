import 'package:flutter/material.dart';

class BudgetFormScreen extends StatelessWidget {
  const BudgetFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New budget')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(decoration: InputDecoration(labelText: 'Category')),
          SizedBox(height: 16),
          TextField(decoration: InputDecoration(labelText: 'Monthly amount')),
        ],
      ),
    );
  }
}
