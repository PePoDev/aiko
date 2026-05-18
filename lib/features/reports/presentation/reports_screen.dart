import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ListTile(
        leading: Icon(Icons.picture_as_pdf_outlined),
        title: Text('Monthly financial report'),
        subtitle: Text('Includes period, filters, and export metadata.'),
      ),
    );
  }
}
