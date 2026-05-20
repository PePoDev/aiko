import 'package:flutter/material.dart';

class OnboardingAccountForm extends StatelessWidget {
  const OnboardingAccountForm({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        TextField(decoration: InputDecoration(labelText: 'Account name')),
        SizedBox(height: 16),
        TextField(decoration: InputDecoration(labelText: 'Opening balance')),
      ],
    );
  }
}
