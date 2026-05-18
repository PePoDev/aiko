import 'package:flutter/material.dart';

class BudgetFormScreen extends StatelessWidget {
  const BudgetFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: 'Category')),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'Monthly amount')),
          ],
        ),
      ),
    );
  }
}
