import 'package:flutter/material.dart';

class CalculatorConversionReviewScreen extends StatelessWidget {
  const CalculatorConversionReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.flag_outlined),
      title: Text('Review draft plan'),
      subtitle: Text('Convert this result into a goal, budget, or debt plan.'),
    );
  }
}
