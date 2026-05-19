import 'package:flutter/material.dart';

import 'screen_states.dart';

class ExpansionPlaceholderScreen extends StatelessWidget {
  const ExpansionPlaceholderScreen({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AikoScreenState(
        title: title,
        message: message,
        icon: Icons.auto_awesome_outlined,
      ),
    );
  }
}
