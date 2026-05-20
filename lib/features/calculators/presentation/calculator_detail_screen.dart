import 'package:flutter/material.dart';

class CalculatorDetailScreen extends StatelessWidget {
  const CalculatorDetailScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(decoration: InputDecoration(labelText: 'Amount')),
          SizedBox(height: 16),
          TextField(decoration: InputDecoration(labelText: 'Rate')),
          SizedBox(height: 16),
          Text('Results are estimates, not guarantees.'),
        ],
      ),
    );
  }
}
