import 'package:flutter/material.dart';

class CalculatorDetailScreen extends StatelessWidget {
  const CalculatorDetailScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: 'Amount')),
            SizedBox(height: 12),
            TextField(decoration: InputDecoration(labelText: 'Rate')),
            SizedBox(height: 12),
            Text('Results are estimates, not guarantees.'),
          ],
        ),
      ),
    );
  }
}
