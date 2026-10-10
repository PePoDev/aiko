import 'package:decimal/decimal.dart';

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
/// How it reads a message:
/// 1. OTP / one-time-code messages are ignored outright, even when they quote
///    an amount ("OTP for payment of THB 500.00").
/// 2. Dates, times, masked account/card numbers (x1234, X-1234, ending 4321,
///    บช 1234) and reference numbers are blanked out so they can't be read as
///    the amount.
/// 3. The amount is the first number next to a currency marker (THB, ฿, บาท,
///    USD, $…) or a movement keyword, skipping balances; failing that, the
///    first remaining number. Zero is never an amount.
/// 4. The direction comes from the income/expense keyword nearest that amount,
///    so "Salary payment THB 50,000.00 credited" is income.
///
/// ponytail: heuristic regex + keyword lists (EN + TH). Upgrade path: per-bank
/// templates keyed by sender if a bank's format trips it up.
class BankMessageParser {
  const BankMessageParser();

  // 1,234.50 | 9,000 | 350.00 | 500 — `,` = thousands, `.` = decimal.
  static final _amount = RegExp(
    r'\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?',
  );
  static final _merchant = RegExp(
    r'\b(?:at|to)\s+([A-Za-z0-9][\w&.\- ]{1,30}?)(?=\s+(?:on|for|from|ref|balance|bal|with|via)\b|[.,\n]|$)',
    caseSensitive: false,
  );
  // A captured "merchant" that is really an account ("your account", x1234)
  // or a bare number.
  static final _notMerchant = RegExp(
    r'^(?:your|my|account|acct|a/c|card)\b|(?:^|\s)(?:[x*]+[-x*\d]*\d[-x*\d]*|\d[\d,]*(?:\.\d+)?)(?=\s|$)',
    caseSensitive: false,
  );

  /// One-time codes and security warnings — never a transaction.
  static final _otp = RegExp(
    r"\b(?:otp|one[- ]time|verification code)\b|do not share|don't share|รหัสผ่านใช้ครั้งเดียว|รหัสยืนยัน|ห้ามบอกรหัส|อย่าบอกรหัส",
    caseSensitive: false,
  );

  static const _months =
      r'(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';
  static const _thaiMonths =
      r'(?:ม\.ค\.|ก\.พ\.|มี\.ค\.|เม\.ย\.|พ\.ค\.|มิ\.ย\.|ก\.ค\.|ส\.ค\.|ก\.ย\.|ต\.ค\.|พ\.ย\.|ธ\.ค\.|มกราคม|กุมภาพันธ์|มีนาคม|เมษายน|พฤษภาคม|มิถุนายน|กรกฎาคม|สิงหาคม|กันยายน|ตุลาคม|พฤศจิกายน|ธันวาคม)';

  /// Number-shaped text that is never the amount: blanked before reading.
  static final _noise = [
    // Dates and account/phone numbers: digit groups joined by / or -
    // (13/10/26, 13/10, 2026-10-13, 123-4-56789-0).
    RegExp(r'\d+(?:[/-]\d+)+'),
    // Clock times: 10:25, 10:25:30.
    RegExp(r'\d{1,2}:\d{2}(?::\d{2})?'),
    // Masked account/card numbers: x1234, X-1234, **1234, xxx-x-x1234-x.
    RegExp(r'(?<![a-z])[x*]+[-x*\d]*\d[-x*\d]*', caseSensitive: false),
    // Dates with month names: 13 Oct 2026, Oct 13, 2026, 13 ต.ค. 69.
    RegExp(
      '\\b\\d{1,2}[\\s-]?$_months\\b\\.?(?:[\\s,-]*\\d{2,4}\\b)?',
      caseSensitive: false,
    ),
    RegExp(
      '\\b$_months\\b\\.?\\s*\\d{1,2}(?:st|nd|rd|th)?\\b(?:,?\\s*\\d{4}\\b)?',
      caseSensitive: false,
    ),
    RegExp('\\d{1,2}\\s*$_thaiMonths\\s*\\d{0,4}'),
  ];

  /// Account, card and reference labels; the number after one (the last
  /// capture group, always the tail of the match) is blanked.
  static final _labelledNumber = RegExp(
    r'(?:\b(?:ending(?:\s+(?:in|with))?|a/c(?:\s*no\.?)?|acct(?:\s*no\.?)?|account\s*(?:no\.?|number)|card\s*(?:no\.?|number)|ref(?:erence)?\b\.?(?:\s*(?:no|code|id)\b\.?)?)|บช|บ/ช|เลขที่อ้างอิง|อ้างอิง)\s*[:#.]?\s*([a-z0-9]*\d[a-z0-9-]*)',
    caseSensitive: false,
  );

  // Credit words are checked against the amount before debit words (see
  // _directionNear); "credit card" / "debit card" name a card, not a movement.
  static final _incomeWords = RegExp(
    r'\b(?:credit(?!\s*cards?\b)|received|deposit|refund|salary|transfer\s+in\b|incoming)|รับโอน|โอนเข้า|เงินเข้า|รับเงิน|ได้รับ|ฝากเงิน|คืนเงิน|เงินเดือน',
    caseSensitive: false,
  );
  static final _expenseWords = RegExp(
    r'\b(?:debit(?!\s*cards?\b)|spent|paid|payment|purchase|charge|withdr[ae]w|transfer\s+out\b)|ถูกหัก|หักเงิน|หักบัญชี|ชำระ|จ่าย|ถอน|โอนออก|เงินออก',
    caseSensitive: false,
  );
  static final _balanceWords = RegExp(
    r'\b(?:balance|bal|avail(?:able)?|avl|ledger)\b|คงเหลือ|ยอดเงิน|ใช้ได้|วงเงิน',
    caseSensitive: false,
  );

  static const _currencyCodes = {
    'thb',
    'usd',
    'eur',
    'gbp',
    'jpy',
    'sgd',
    'cny',
    'hkd',
    'aud',
    'baht',
  };
  static final _currencyBefore = RegExp(
    r'(?:\b(?:thb|usd|eur|gbp|jpy|sgd|cny|hkd|aud|baht)|[฿$€£¥])\s*$',
    caseSensitive: false,
  );
  // "บ" alone (500.00บ) is baht; "บช" right after a number is an account.
  static final _currencyAfter = RegExp(
    r'^\s*(?:(?:thb|usd|eur|gbp|jpy|sgd|cny|hkd|aud|baht)\b|บาท|บ(?![\u0E00-\u0E7F])|฿)',
    caseSensitive: false,
  );
  static final _lettersBefore = RegExp(r'[a-z]+$', caseSensitive: false);
  static final _lettersAfter = RegExp(r'^[a-z]+', caseSensitive: false);

  ParsedCapture? parse(String text) {
    if (text.trim().isEmpty) return null;
    if (_otp.hasMatch(text)) return null; // codes, not money movements

    final masked = _maskNoise(text);
    final amount = _pickAmount(masked);
    if (amount == null) return null;

    final type = _directionNear(masked, amount);
    if (type == null) return null; // not a money movement we recognise

    return ParsedCapture(
      amount: amount.group(0)!.replaceAll(',', ''),
      type: type,
      merchant: _extractMerchant(text),
    );
  }

  /// [text] with dates, times and account/reference numbers replaced by
  /// spaces (same length, so offsets still line up with the original).
  String _maskNoise(String text) {
    final chars = text.split('');
    void blank(int start, int end) {
      for (var i = start; i < end; i++) {
        chars[i] = ' ';
      }
    }

    for (final pattern in _noise) {
      for (final m in pattern.allMatches(text)) {
        blank(m.start, m.end);
      }
    }
    for (final m in _labelledNumber.allMatches(text)) {
      blank(m.end - m.group(1)!.length, m.end);
    }
    return chars.join();
  }

  /// The movement amount: the first positive number tied to a currency marker
  /// or movement keyword, else the first positive non-balance number.
  RegExpMatch? _pickAmount(String masked) {
    RegExpMatch? fallback;
    var previousEnd = 0;
    for (final match in _amount.allMatches(masked)) {
      final contextStart = (match.start - 24).clamp(previousEnd, match.start);
      final context = masked.substring(contextStart, match.start);
      previousEnd = match.end;

      if (!_isStandalone(masked, match)) continue; // part of a code/word
      if (_balanceWords.hasMatch(context)) continue; // "balance: X"
      final value = Decimal.tryParse(match.group(0)!.replaceAll(',', ''));
      if (value == null || value <= Decimal.zero) continue;

      final before = masked.substring(0, match.start);
      final after = masked.substring(match.end);
      if (_currencyBefore.hasMatch(before) ||
          _currencyAfter.hasMatch(after) ||
          _incomeWords.hasMatch(context) ||
          _expenseWords.hasMatch(context)) {
        return match;
      }
      fallback ??= match;
    }
    return fallback;
  }

  /// False when the number is glued to other digits or to letters that
  /// aren't a currency code (e.g. "ABC123", "1,2345").
  bool _isStandalone(String masked, RegExpMatch match) {
    final before = masked.substring(0, match.start);
    final after = masked.substring(match.end);
    if (before.isNotEmpty && RegExp(r'[\d.,]$').hasMatch(before)) {
      return false;
    }
    if (after.isNotEmpty && RegExp(r'^(?:\d|[.,]\d)').hasMatch(after)) {
      return false;
    }
    final lettersBefore = _lettersBefore.firstMatch(before)?.group(0);
    if (lettersBefore != null &&
        !_currencyCodes.contains(lettersBefore.toLowerCase())) {
      return false;
    }
    final lettersAfter = _lettersAfter.firstMatch(after)?.group(0);
    if (lettersAfter != null &&
        !_currencyCodes.contains(lettersAfter.toLowerCase())) {
      return false;
    }
    return true;
  }

  /// Income or expense, from the keyword closest to [amount] (either side).
  /// On a tie the income keyword wins.
  TransactionType? _directionNear(String masked, RegExpMatch amount) {
    int? nearest(RegExp words) {
      int? best;
      for (final m in words.allMatches(masked)) {
        final gap = m.end <= amount.start
            ? amount.start - m.end
            : m.start >= amount.end
            ? m.start - amount.end
            : 0;
        if (best == null || gap < best) best = gap;
      }
      return best;
    }

    final income = nearest(_incomeWords);
    final expense = nearest(_expenseWords);
    if (income == null && expense == null) return null;
    if (expense == null) return TransactionType.income;
    if (income == null) return TransactionType.expense;
    return income <= expense ? TransactionType.income : TransactionType.expense;
  }

  String? _extractMerchant(String text) {
    final raw = _merchant.firstMatch(text)?.group(1)?.trim();
    if (raw == null || raw.isEmpty || _notMerchant.hasMatch(raw)) return null;
    return raw.replaceAll(RegExp(r'\s+'), ' ');
  }
}
