import 'dart:async';
import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';

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

class ReceiptOcrJob {
  const ReceiptOcrJob({
    required this.attachmentId,
    required this.storagePath,
    this.status = ReceiptOcrJobStatus.queued,
  });

  final String attachmentId;
  final String storagePath;
  final ReceiptOcrJobStatus status;
}

enum ReceiptOcrJobStatus { queued, processing, completed, failed }

class ReceiptOcrService {
  const ReceiptOcrService();

  Future<ReceiptAutofill> scanWithCloudOcr({
    required List<int> imageBytes,
    required String fileName,
    String currency = 'THB',
  }) async {
    final client = AikoSupabase.tryClient();
    if (client == null) {
      return parseRecognizedText('', currency: currency);
    }

    try {
      final response = await client.functions.invoke(
        'ocr-scanner',
        body: {'fileName': fileName, 'imageBytes': imageBytes},
      );
      final data = response.data as Map<String, dynamic>;
      final recognizedText = data['recognizedText'] as String? ?? '';
      return parseRecognizedText(recognizedText, currency: currency);
    } catch (_) {
      return parseRecognizedText('', currency: currency);
    }
  }

  ReceiptOcrJob queueServerRecognition({
    required String attachmentId,
    required String userId,
    required String fileName,
  }) {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return ReceiptOcrJob(
      attachmentId: attachmentId,
      storagePath: 'receipts/$userId/$attachmentId/$cleanName',
    );
  }

  ReceiptAutofill parseRecognizedText(String text, {String currency = 'THB'}) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final merchant = lines.isEmpty ? null : lines.first;
    final total = _extractTotal(lines, currency);
    final date = _extractDate(lines);
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
      (line) => RegExp(
        r'\b(total|amount due|paid)\b',
        caseSensitive: false,
      ).hasMatch(line),
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

  DateTime? _extractDate(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(
        r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b',
      ).firstMatch(line);
      if (match != null) {
        final month = int.parse(match.group(1)!);
        final day = int.parse(match.group(2)!);
        var year = int.parse(match.group(3)!);
        if (year < 100) {
          year += 2000;
        }
        return DateTime(year, month, day);
      }
    }
    return null;
  }
}
