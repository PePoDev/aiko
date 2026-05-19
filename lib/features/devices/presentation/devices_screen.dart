import 'package:flutter/material.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Devices')),
    body: ListView(
      padding: EdgeInsets.all(16),
      children: const [
        ListTile(
          title: Text('Trusted devices'),
          subtitle: Text('Manage sessions and remote sign-out.'),
        ),
        ListTile(
          title: Text('Sync conflicts'),
          subtitle: Text('Review conflicts before overwriting data.'),
        ),
      ],
    ),
  );
}
