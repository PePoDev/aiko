import 'package:flutter/material.dart';

class AikoOptimizeScreen extends StatelessWidget {
  const AikoOptimizeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aiko Optimize')),
    body: ListView(
      padding: EdgeInsets.all(16),
      children: const [
        ListTile(
          title: Text('Optimization suggestions'),
          subtitle: Text('Ranked, explainable next steps.'),
        ),
        ListTile(
          title: Text('Prediction scenarios'),
          subtitle: Text('Expected range with freshness checks.'),
        ),
      ],
    ),
  );
}
