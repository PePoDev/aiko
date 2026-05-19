import 'package:flutter/material.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Portfolio')),
    body: ListView(
      padding: EdgeInsets.all(16),
      children: const [
        ListTile(
          title: Text('Holdings'),
          subtitle: Text('Track value, gains, dividends, and fees.'),
        ),
        ListTile(
          title: Text('Allocation drift'),
          subtitle: Text('Compare current holdings with target allocation.'),
        ),
      ],
    ),
  );
}
