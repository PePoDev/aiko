import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../application/accounting_service.dart';
import '../domain/accounting_record.dart';

class AccountingScreen extends StatelessWidget {
  const AccountingScreen({super.key});

  static const _service = AccountingService();

  @override
  Widget build(BuildContext context) {
    final record = AccountingRecord(
      entryType: 'Software subscription',
      amount: Money.parse('49', 'USD'),
      debitAccount: 'Software Expense',
      creditAccount: 'Cash',
    );
    final journal = _service.journalEntryFor(record);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounting')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          const FinanceCard(
            title: 'Business mode',
            icon: Icons.business_center_outlined,
            accentColor: AikoColors.neutralInk,
            child: Text('Separate personal and business records.'),
          ),
          const SizedBox(height: 16),
          const FinanceCard(
            title: 'Reconciliation',
            icon: Icons.rule_folder_outlined,
            accentColor: AikoColors.analyticsTeal,
            child: Text('Review pending accounting entries.'),
          ),
          const SizedBox(height: 16),
          FinanceCard(
            title: 'Double-entry journal',
            icon: Icons.fact_check_outlined,
            accentColor: AikoColors.analyticsTeal,
            child: Column(
              children: [
                for (final line in journal.lines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(line.account),
                    subtitle: Text(line.side.name),
                    trailing: Text(line.amount.format()),
                  ),
                Text(
                  journal.isBalanced
                      ? 'Journal is balanced.'
                      : 'Review journal balance.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
