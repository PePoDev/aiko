import 'package:flutter/material.dart';

class TravelModeScreen extends StatelessWidget {
  const TravelModeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Travel Mode')),
    body: ListView(
      padding: EdgeInsets.all(16),
      children: const [
        ListTile(
          title: Text('Trip budget'),
          subtitle: Text('Track local and home currency views.'),
        ),
        ListTile(
          title: Text('Foreign fees'),
          subtitle: Text('Monitor exchange and card fee costs.'),
        ),
      ],
    ),
  );
}
