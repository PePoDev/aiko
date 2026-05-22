import '../../../core/money/money.dart';

enum AccountingMode { simple, advanced }

enum ReconciliationStatus { pending, reconciled }

class AccountingRecord {
  const AccountingRecord({
    required this.entryType,
    required this.amount,
    this.debitAccount = 'Uncategorized',
    this.creditAccount = 'Uncategorized',
    this.status = ReconciliationStatus.pending,
  });

  final String entryType;
  final Money amount;
  final String debitAccount;
  final String creditAccount;
  final ReconciliationStatus status;

  bool get isReconciled => status == ReconciliationStatus.reconciled;
}

class JournalEntry {
  const JournalEntry({required this.memo, required this.lines});

  final String memo;
  final List<JournalLine> lines;

  bool get isBalanced {
    if (lines.isEmpty) {
      return false;
    }
    final currency = lines.first.amount.currency;
    final debitTotal = lines
        .where((line) => line.side == JournalSide.debit)
        .fold(Money.zero(currency), (sum, line) => sum + line.amount);
    final creditTotal = lines
        .where((line) => line.side == JournalSide.credit)
        .fold(Money.zero(currency), (sum, line) => sum + line.amount);
    return debitTotal == creditTotal;
  }
}

class JournalLine {
  const JournalLine({
    required this.account,
    required this.side,
    required this.amount,
  });

  final String account;
  final JournalSide side;
  final Money amount;
}

enum JournalSide { debit, credit }
