import 'package:flutter/material.dart';

class CreditCardOverviewScreen extends StatelessWidget {
  const CreditCardOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Credit Cards')),
    body: ListView(
      padding: EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: Icon(Icons.credit_card_outlined),
          title: Text('Utilization'),
          subtitle: Text(
            'Track limits, balances, APR, rewards, and due dates.',
          ),
        ),
        ListTile(
          leading: Icon(Icons.payments_outlined),
          title: Text('Payment planning'),
          subtitle: Text('Review minimum payment and interest estimates.'),
        ),
      ],
    ),
  );
}
