import 'package:flutter/material.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: ListTile(
          leading: Icon(Icons.file_download_outlined),
          title: Text('Export CSV'),
          subtitle: Text(
            'Choose date range and confirm sensitive financial data export before sharing the file.',
          ),
        ),
      ),
    );
  }
}
