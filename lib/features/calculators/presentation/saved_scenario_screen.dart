import 'package:flutter/material.dart';

class SavedScenarioScreen extends StatelessWidget {
  const SavedScenarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.bookmark_outline),
      title: Text('Saved calculator scenario'),
    );
  }
}
