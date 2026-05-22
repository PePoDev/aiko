import '../../../core/money/money.dart';
import '../domain/accounting_record.dart';

class AccountingService {
  const AccountingService();

  List<AccountingRecord> pendingReconciliation(List<AccountingRecord> records) {
    return records
        .where((record) => record.status == ReconciliationStatus.pending)
        .toList(growable: false);
  }

  JournalEntry journalEntryFor(AccountingRecord record) {
    return JournalEntry(
      memo: record.entryType,
      lines: [
        JournalLine(
          account: record.debitAccount,
          side: JournalSide.debit,
          amount: record.amount,
        ),
        JournalLine(
          account: record.creditAccount,
          side: JournalSide.credit,
          amount: record.amount,
        ),
      ],
    );
  }

  Money ledgerBalance({
    required String account,
    required List<JournalEntry> entries,
    required String currency,
  }) {
    return entries
        .expand((entry) => entry.lines)
        .where((line) {
          return line.account == account && line.amount.currency == currency;
        })
        .fold(Money.zero(currency), (balance, line) {
          return switch (line.side) {
            JournalSide.debit => balance + line.amount,
            JournalSide.credit => balance - line.amount,
          };
        });
  }
}
