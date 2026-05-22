import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/aiko_navigation.dart';
import '../../../shared/widgets/finance_card.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          const FinanceCard(
            title: 'Aiko workspace',
            icon: Icons.apps_outlined,
            prominent: true,
            child: Text(
              'Every feature area is grouped here so secondary pages stay reachable without crowding the main tabs.',
            ),
          ),
          const SizedBox(height: 16),
          for (final group in aikoNavigationGroups) ...[
            Text(group.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final item in group.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MoreTile(item: item),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.item});

  final AikoNavigationItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.icon, color: item.accentColor),
        ),
        title: Text(item.label),
        subtitle: item.description.isEmpty ? null : Text(item.description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(item.path),
      ),
    );
  }
}
