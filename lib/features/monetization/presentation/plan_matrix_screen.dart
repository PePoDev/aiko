import 'package:flutter/material.dart';

class PlanMatrixScreen extends StatelessWidget {
  const PlanMatrixScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Subscription Plan')),
    body: ListView(
      padding: EdgeInsets.all(16),
      children: const [
        ListTile(
          title: Text('Free'),
          subtitle: Text('Manual tracking and basic insights.'),
        ),
        ListTile(
          title: Text('Premium'),
          subtitle: Text('Forecasting, reports, sync, and advanced insights.'),
        ),
        ListTile(
          title: Text('Pro'),
          subtitle: Text('Accounting, tax, business, and advanced planning.'),
        ),
      ],
    ),
  );
}
