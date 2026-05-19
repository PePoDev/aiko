import 'package:flutter/material.dart';

class LearningHubScreen extends StatelessWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Learning Hub')),
    body: ListView(
      padding: EdgeInsets.all(16),
      children: const [
        ListTile(
          title: Text('Recommended lessons'),
          subtitle: Text('Aiko suggests personal finance topics.'),
        ),
        ListTile(
          title: Text('Quizzes'),
          subtitle: Text('Track learning progress and scores.'),
        ),
        ListTile(
          title: Text('Glossary'),
          subtitle: Text('Look up financial terms quickly.'),
        ),
      ],
    ),
  );
}
