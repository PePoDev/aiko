import '../../../core/money/money.dart';
import '../domain/transaction.dart';

class VoiceTransactionDraft {
  const VoiceTransactionDraft({
    required this.type,
    required this.amount,
    required this.date,
    this.merchant,
    this.note,
  });

  final TransactionType type;
  final Money amount;
  final DateTime date;
  final String? merchant;
  final String? note;
}

class VoiceTransactionParser {
  const VoiceTransactionParser();

  VoiceTransactionDraft parse(
    String input, {
    required DateTime now,
    String currency = 'USD',
  }) {
    final normalized = input.trim().toLowerCase();
    final amount = _amount(normalized, currency);
    final type =
        RegExp(r'\b(earned|received|income|paid me)\b').hasMatch(normalized) ||
            _thaiIncome.hasMatch(normalized)
        ? TransactionType.income
        : TransactionType.expense;
    return VoiceTransactionDraft(
      type: type,
      amount: amount,
      date: _date(normalized, now),
      // The transcript as typed, so the merchant keeps its casing.
      merchant: _merchant(input.trim()),
      note: input.trim(),
    );
  }

  /// Thai income phrases ("ได้รับเงิน", "เงินเดือนเข้า", "รายได้"). Thai has
  /// no spaces between words, so these match anywhere in the phrase.
  static final _thaiIncome = RegExp('ได้รับ|ได้เงิน|รับเงิน|รายได้|เงินเดือน');

  Money _amount(String input, String currency) {
    final numeric = RegExp(
      r'(?:\$|usd\s*|฿\s*)?(\d{1,3}(?:,\d{3})+|\d+)(\.\d{1,2})?',
    ).firstMatch(input);
    if (numeric != null) {
      final whole = numeric.group(1)!.replaceAll(',', '');
      return Money.parse('$whole${numeric.group(2) ?? ''}', currency);
    }
    final words = <String, String>{
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'ten': '10',
      'twenty': '20',
      'fifty': '50',
      'hundred': '100',
    };
    for (final entry in words.entries) {
      if (RegExp('\\b${entry.key}\\b').hasMatch(input)) {
        return Money.parse(entry.value, currency);
      }
    }
    throw ArgumentError('Could not find a transaction amount.');
  }

  DateTime _date(String input, DateTime now) {
    if (input.contains('yesterday') || input.contains('เมื่อวาน')) {
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
    }
    if (input.contains('tomorrow') || input.contains('พรุ่งนี้')) {
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
    }
    return DateTime(now.year, now.month, now.day);
  }

  // "at"/"from" name a place; "on"/"for" more often name what was bought, so
  // they are only a fallback ("for lunch at KFC" → KFC).
  static final _merchantAfter = [
    RegExp(r"\b(?:at|from)\s+([a-z0-9][a-z0-9 &.'-]*)", caseSensitive: false),
    RegExp(r"\b(?:on|for)\s+([a-z0-9][a-z0-9 &.'-]*)", caseSensitive: false),
  ];

  /// Where a merchant name ends: date words and connectives ("Amazon
  /// yesterday", "Starbucks for coffee", "สตาร์บัคส์เมื่อวาน").
  static final _merchantEnd = RegExp(
    r'\s+(?:yesterday|today|tonight|tomorrow|last|on|for|with|at|from)\b|เมื่อวาน|วันนี้|พรุ่งนี้|เมื่อ',
    caseSensitive: false,
  );

  String? _merchant(String input) {
    for (final pattern in _merchantAfter) {
      final name = _trimMerchant(pattern.firstMatch(input)?.group(1));
      if (name != null) return name;
    }
    // Thai: "…ที่ร้านสตาร์บัคส์ เมื่อวาน" → the word after ที่(ร้าน) or จาก(ร้าน).
    final thai = RegExp(r'(?:ที่|จาก)(?:ร้าน)?\s*([^\s\d]+)').firstMatch(input);
    return _trimMerchant(thai?.group(1));
  }

  String? _trimMerchant(String? raw) {
    if (raw == null) return null;
    final end = _merchantEnd.firstMatch(raw);
    final name = (end == null ? raw : raw.substring(0, end.start))
        .replaceFirst(RegExp(r"[\s.,'-]+$"), '') // "Amazon." → "Amazon"
        .trim();
    return name.isEmpty ? null : name;
  }
}
