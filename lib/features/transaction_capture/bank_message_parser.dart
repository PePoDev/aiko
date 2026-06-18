import '../transactions/domain/transaction.dart';

/// Result of reading a bank SMS / notification: the amount (decimal string),
/// the inferred transaction direction, and a best-effort merchant.
class ParsedCapture {
  const ParsedCapture({
    required this.amount,
    required this.type,
    this.merchant,
  });

  final String amount;
  final TransactionType type;
  final String? merchant;
}

/// Turns a raw bank message into a draft transaction, or null when the text
/// doesn't look like a money movement (OTPs, marketing, balance-only pings).
///
/// ponytail: heuristic regex + keyword lists (EN + TH). Good enough for the
/// common "spent/received X at Y, balance Z" shape. Upgrade path: per-bank
/// templates keyed by sender if a bank's format trips it up.
class BankMessageParser {
  const BankMessageParser();

  // 1,234.50 | 9,000 | 350.00 | 500 — `,` = thousands, `.` = decimal.
  static final _amount = RegExp(r'\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?');
  static final _merchant = RegExp(
    r'\b(?:at|to)\s+([A-Za-z0-9][\w&.\- ]{1,30}?)(?=\s+(?:on|for|ref|balance|bal)\b|[.,\n]|$)',
    caseSensitive: false,
  );

  static const _expenseWords = [
    'debit', 'debited', 'spent', 'paid', 'payment', 'purchase', 'charged',
    'withdrawn', 'withdrawal', 'ถูกหัก', 'ชำระ', 'จ่าย', 'ออก',
  ];
  static const _incomeWords = [
    'credit', 'credited', 'received', 'deposit', 'deposited', 'refund',
    'salary', 'transfer in', 'เข้า', 'รับเงิน', 'โอนเข้า',
  ];
  static const _balanceWords = [
    'balance', 'bal', 'available', 'avail', 'คงเหลือ', 'ยอดเงิน',
  ];

  ParsedCapture? parse(String text) {
    if (text.trim().isEmpty) return null;
    final lower = text.toLowerCase();

    final TransactionType? type = _expenseWords.any(lower.contains)
        ? TransactionType.expense
        : _incomeWords.any(lower.contains)
        ? TransactionType.income
        : null;
    if (type == null) return null; // not a money movement we recognise

    final amount = _firstNonBalanceAmount(text, lower);
    if (amount == null) return null;

    return ParsedCapture(
      amount: amount,
      type: type,
      merchant: _extractMerchant(text),
    );
  }

  String? _firstNonBalanceAmount(String text, String lower) {
    for (final match in _amount.allMatches(text)) {
      final before = lower.substring(
        (match.start - 15).clamp(0, lower.length),
        match.start,
      );
      if (_balanceWords.any(before.contains)) continue; // skip "balance: X"
      return match.group(0)!.replaceAll(',', '');
    }
    return null;
  }

  String? _extractMerchant(String text) {
    final raw = _merchant.firstMatch(text)?.group(1)?.trim();
    if (raw == null || raw.isEmpty || _amount.hasMatch(raw)) return null;
    return raw.replaceAll(RegExp(r'\s+'), ' ');
  }
}
