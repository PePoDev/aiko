import 'package:flutter/material.dart';

class UpgradePrompt extends StatelessWidget {
  const UpgradePrompt({required this.featureName, super.key});

  final String featureName;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Upgrade'),
    content: Text('$featureName is available with a higher plan.'),
  );
}
