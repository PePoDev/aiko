import 'dart:convert';

import '../../../core/money/money.dart';
import '../../../core/firebase/firebase_backend.dart';

class ReceiptAutofill {
  const ReceiptAutofill({
    this.merchant,
    this.total,
    this.date,
    this.confidence = 0,
    this.sourceLines = const [],
  });

  final String? merchant;
  final Money? total;
  final DateTime? date;
  final double confidence;
  final List<String> sourceLines;

  bool get hasTransactionFields => merchant != null || total != null;
}

class ReceiptOcrService {
  const ReceiptOcrService();

  Future<ReceiptAutofill> scanWithCloudOcr({
    required List<int> imageBytes,
    required String fileName,
    String currency = 'THB',
  }) async {
    if (!FirebaseBackend.isConfigured) {
      return parseRecognizedText('', currency: currency);
    }

    try {
      final response = await FirebaseBackend.functions
          .httpsCallable('ocrScanner')
          .call(cloudOcrRequest(imageBytes: imageBytes, fileName: fileName));
      final data = response.data as Map<String, dynamic>;
      final recognizedText = data['recognizedText'] as String? ?? '';
      return parseRecognizedText(recognizedText, currency: currency);
    } catch (_) {
      return parseRecognizedText('', currency: currency);
    }
  }

  /// The `ocrScanner` request. The image travels as base64, about a third
  /// larger than the image; a JSON array of integers was 3–4 times larger.
  static Map<String, Object> cloudOcrRequest({
    required List<int> imageBytes,
    required String fileName,
  }) => {'fileName': fileName, 'imageBase64': base64Encode(imageBytes)};

  /// [now] (default: the clock) bounds which dates count as plausible.
  ReceiptAutofill parseRecognizedText(
    String text, {
    String currency = 'THB',
    DateTime? now,
  }) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final merchant = lines.isEmpty ? null : lines.first;
    final total = _extractTotal(lines, currency);
    final date = extractDate(lines, now: now);
    final populated = [merchant, total, date].where((value) => value != null);

    return ReceiptAutofill(
      merchant: merchant,
      total: total,
      date: date,
      confidence: populated.length / 3,
      sourceLines: lines.take(8).toList(growable: false),
    );
  }

  Money? _extractTotal(List<String> lines, String currency) {
    final totalLine = lines.lastWhere(
      (line) =>
          RegExp(
            r'\b(total|amount due|paid)\b',
            caseSensitive: false,
          ).hasMatch(line) ||
          // Thai receipts: "ยอดรวม", "รวมทั้งสิ้น", "ยอดสุทธิ", "ยอดชำระ"…
          RegExp('รวม|สุทธิ|ยอดชำระ|จำนวนเงิน').hasMatch(line),
      orElse: () => '',
    );
    final candidates = [if (totalLine.isNotEmpty) totalLine, ...lines.reversed];
    for (final line in candidates) {
      final matches = RegExp(
        r'(\d{1,6}(?:[,.]\d{3})*(?:\.\d{2})?)',
      ).allMatches(line).toList(growable: false);
      if (matches.isNotEmpty) {
        return Money.parse(
          matches.last.group(1)!.replaceAll(',', ''),
          currency,
        );
      }
    }
    return null;
  }

  static final _datePattern = RegExp(
    r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b',
  );
  static final _monthFirstMarker = RegExp(
    r'\bmm[/-]dd\b',
    caseSensitive: false,
  );

  /// The receipt's date: the first d/m/y on any line that is a real calendar
  /// date the transaction form can show, or null.
  ///
  /// - Day first (05/10/2026 = 5 October), as Thai receipts print it. Month
  ///   first only when the middle number can't be a month (05/21/2026) or the
  ///   receipt labels its dates MM/DD; never for Buddhist-era years.
  /// - Four-digit years above 2400 are Buddhist era (2569 = 2026). A two-digit
  ///   year more than one ahead of this year's (69 in 2026) is a Buddhist year
  ///   too (2569); otherwise it is 20xx.
  /// - Dates after tomorrow or before the date picker's first year (five years
  ///   back) are skipped.
  static DateTime? extractDate(List<String> lines, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final earliest = DateTime(today.year - 5);
    final latest = DateTime(today.year, today.month, today.day + 1);
    final monthFirstLabel = lines.any(_monthFirstMarker.hasMatch);

    for (final line in lines) {
      for (final match in _datePattern.allMatches(line)) {
        final first = int.parse(match.group(1)!);
        final second = int.parse(match.group(2)!);
        var year = int.parse(match.group(3)!);
        var buddhistEra = year > 2400;
        if (year < 100) {
          buddhistEra = year > today.year % 100 + 1;
          year += buddhistEra ? 2500 : 2000;
        }
        if (buddhistEra) year -= 543;

        final monthFirst =
            !buddhistEra && first <= 12 && (second > 12 || monthFirstLabel);
        final month = monthFirst ? first : second;
        final day = monthFirst ? second : first;
        if (month < 1 || month > 12 || day < 1) continue;
        final date = DateTime(year, month, day);
        if (date.month != month) continue; // 31/02 would roll into March
        if (date.isBefore(earliest) || date.isAfter(latest)) continue;
        return date;
      }
    }
    return null;
  }
}
