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
        RegExp(r'\b(earned|received|income|paid me)\b').hasMatch(normalized)
        ? TransactionType.income
        : TransactionType.expense;
    return VoiceTransactionDraft(
      type: type,
      amount: amount,
      date: _date(normalized, now),
      merchant: _merchant(normalized),
      note: input.trim(),
    );
  }

  Money _amount(String input, String currency) {
    final numeric = RegExp(
      r'(?:\$|usd\s*)?(\d+(?:\.\d{1,2})?)',
    ).firstMatch(input);
    if (numeric != null) {
      return Money.parse(numeric.group(1)!, currency);
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
    if (input.contains('yesterday')) {
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
    }
    if (input.contains('tomorrow')) {
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
    }
    return DateTime(now.year, now.month, now.day);
  }

  String? _merchant(String input) {
    final match = RegExp(
      r'\b(?:at|on|for|from)\s+([a-z0-9 &.-]+)',
    ).firstMatch(input);
    return match?.group(1)?.trim();
  }
}
