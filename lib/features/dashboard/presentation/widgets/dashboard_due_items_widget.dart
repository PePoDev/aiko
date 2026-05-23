import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/finance_card.dart';
import '../../domain/dashboard_due_item.dart';

class DashboardDueItemsWidget extends StatelessWidget {
  const DashboardDueItemsWidget({required this.items, super.key});

  final List<DashboardDueItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (items.isEmpty) {
      return FinanceCard(
        title: l10n.upcomingDueDates,
        icon: Icons.event_available_outlined,
        child: Text(l10n.noDueDates),
      );
    }

    return FinanceCard(
      title: l10n.upcomingDueDates,
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
