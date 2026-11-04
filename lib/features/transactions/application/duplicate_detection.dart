import '../domain/transaction.dart';

/// The saved transaction that [candidate] most likely repeats, or null: same
/// account, type and amount, dated the same day or one day apart, with the
/// same item name or category. Voided and archived rows don't count.
FinanceTransaction? findLikelyDuplicate(
  FinanceTransaction candidate,
  Iterable<FinanceTransaction> saved,
) {
  final merchant = _normalize(candidate.merchant);
  final day = _dateOnly(candidate.date);
  for (final other in saved) {
    if (other.id == candidate.id ||
        other.status == TransactionStatus.voided ||
        other.status == TransactionStatus.archived ||
        other.accountId != candidate.accountId ||
        other.type != candidate.type ||
        other.amount != candidate.amount ||
        _dateOnly(other.date).difference(day).inDays.abs() > 1) {
      continue;
    }
    final sameMerchant =
        merchant.isNotEmpty && _normalize(other.merchant) == merchant;
    final sameCategory =
        candidate.categoryId != null &&
        other.categoryId == candidate.categoryId;
    if (sameMerchant || sameCategory) return other;
  }
  return null;
}

String _normalize(String? text) => (text ?? '').trim().toLowerCase();

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
