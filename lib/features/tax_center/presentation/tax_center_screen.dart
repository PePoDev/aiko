import 'package:flutter/material.dart';

class TaxCenterScreen extends StatelessWidget {
  const TaxCenterScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tax Center')),
    body: ListView(
      padding: EdgeInsets.all(16),
      children: const [
        ListTile(
          title: Text('Tax estimates'),
          subtitle: Text('Organize tax-year income and deductions.'),
        ),
        ListTile(
          title: Text('Tax disclaimer'),
          subtitle: Text(
            'Aiko tax outputs are estimates, not professional advice.',
          ),
        ),
      ],
    ),
  );
}
