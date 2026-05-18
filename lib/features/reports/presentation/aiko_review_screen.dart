import 'package:flutter/material.dart';

class AikoReviewScreen extends StatelessWidget {
  const AikoReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: ListTile(
          leading: Icon(Icons.summarize_outlined),
          title: Text('Aiko Review'),
          subtitle: Text(
            'Budget performance, goal progress, and next steps. Aiko guidance is an estimate and does not replace professional financial advice.',
          ),
        ),
      ),
    );
  }
}
