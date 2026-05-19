import 'package:flutter/material.dart';

class AccountingScreen extends StatelessWidget {
  const AccountingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Accounting')),
    body: ListView(
      padding: EdgeInsets.all(16),
      children: const [
        ListTile(
          title: Text('Business mode'),
          subtitle: Text('Separate personal and business records.'),
        ),
        ListTile(
          title: Text('Reconciliation'),
          subtitle: Text('Review pending accounting entries.'),
        ),
      ],
    ),
  );
}
