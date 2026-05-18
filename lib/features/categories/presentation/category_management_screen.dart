import 'package:flutter/material.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ListTile(
        leading: Icon(Icons.category_outlined),
        title: Text('Food and Dining'),
        subtitle: Text('Needs • Budget enabled'),
      ),
    );
  }
}
