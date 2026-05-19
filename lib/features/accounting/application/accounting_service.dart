import '../domain/accounting_record.dart';

class AccountingService {
  const AccountingService();

  List<AccountingRecord> pendingReconciliation(List<AccountingRecord> records) {
    return records
        .where((record) => record.status == ReconciliationStatus.pending)
        .toList(growable: false);
  }
}
