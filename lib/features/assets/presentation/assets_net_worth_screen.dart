import 'package:flutter/material.dart';

class AssetsNetWorthScreen extends StatelessWidget {
  const AssetsNetWorthScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Assets and Net Worth')),
    body: ListView(
      padding: EdgeInsets.all(16),
      children: const [
        ListTile(
          title: Text('Net worth'),
          subtitle: Text('Assets minus liabilities.'),
        ),
        ListTile(
          title: Text('Asset allocation'),
          subtitle: Text('Cash, investments, property, and other assets.'),
        ),
      ],
    ),
  );
}
