import 'package:flutter/material.dart';

class TransactionRulesScreen extends StatelessWidget {
  const TransactionRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction rules')),
      body: const ListTile(
        leading: Icon(Icons.rule),
        title: Text('If merchant contains Netflix'),
        subtitle: Text('Category: Subscriptions • Tag: Entertainment'),
      ),
    );
  }
}
