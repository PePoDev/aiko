import 'package:flutter/material.dart';

import '../../../../shared/widgets/finance_card.dart';
import '../../domain/dashboard_due_item.dart';

class DashboardDueItemsWidget extends StatelessWidget {
  const DashboardDueItemsWidget({required this.items, super.key});

  final List<DashboardDueItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const FinanceCard(
        title: 'Upcoming due dates',
        icon: Icons.event_available_outlined,
        child: Text('No bills or card payments due soon.'),
      );
    }

    return FinanceCard(
      title: 'Upcoming due dates',
      icon: Icons.event_note_outlined,
      child: Column(
        children: [
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.kind == DashboardDueItemKind.bill
                    ? Icons.receipt_long_outlined
                    : Icons.credit_card_outlined,
              ),
              title: Text(item.title),
              subtitle: Text(_dueLabel(item.dueDate)),
              trailing: Text(item.amount.format()),
            ),
        ],
      ),
    );
  }

  String _dueLabel(DateTime dueDate) {
    return 'Due ${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
  }
}
