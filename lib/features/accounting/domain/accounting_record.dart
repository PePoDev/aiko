import '../../../core/money/money.dart';

enum AccountingMode { simple, advanced }

enum ReconciliationStatus { pending, reconciled }

class AccountingRecord {
  const AccountingRecord({
    required this.entryType,
    required this.amount,
    this.status = ReconciliationStatus.pending,
  });

  final String entryType;
  final Money amount;
  final ReconciliationStatus status;

  bool get isReconciled => status == ReconciliationStatus.reconciled;
}
