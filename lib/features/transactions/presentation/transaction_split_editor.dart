import 'package:flutter/material.dart';

class TransactionSplitEditor extends StatelessWidget {
  const TransactionSplitEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        TextField(decoration: InputDecoration(labelText: 'Split category')),
        SizedBox(height: 12),
        TextField(decoration: InputDecoration(labelText: 'Split amount')),
      ],
    );
  }
}
