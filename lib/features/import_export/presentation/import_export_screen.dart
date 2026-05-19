import 'package:flutter/material.dart';

class ImportExportScreen extends StatelessWidget {
  const ImportExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import, Export, and Backup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.upload_file_outlined),
            title: Text('Preview import'),
            subtitle: Text(
              'Validate mappings, missing fields, and duplicates.',
            ),
          ),
          ListTile(
            leading: Icon(Icons.file_download_outlined),
            title: Text('Export package'),
            subtitle: Text('Choose scope and acknowledge sensitive data.'),
          ),
          ListTile(
            leading: Icon(Icons.cloud_sync_outlined),
            title: Text('Backup status'),
            subtitle: Text('Review snapshots before restore.'),
          ),
        ],
      ),
    );
  }
}
