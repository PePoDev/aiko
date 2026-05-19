import 'package:flutter/material.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bills and Subscriptions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.event_available_outlined),
            title: Text('Upcoming bills'),
            subtitle: Text(
              'Renewals and due dates appear with Aiko reminders.',
            ),
          ),
          ListTile(
            leading: Icon(Icons.subscriptions_outlined),
            title: Text('Subscription review'),
            subtitle: Text('Annualized costs and cancellation candidates.'),
          ),
          ListTile(
            leading: Icon(Icons.savings_outlined),
            title: Text('Lower your bills'),
            subtitle: Text('Review price changes and savings opportunities.'),
          ),
        ],
      ),
    );
  }
}
