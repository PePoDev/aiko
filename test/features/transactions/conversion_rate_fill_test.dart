import 'package:aiko/core/money/exchange_rates.dart';
import 'package:aiko/features/transactions/application/conversion_rate_fill.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final savedAt = DateTime(2026, 10, 15, 8);
  const empty = (text: '', note: null);

  group('fillConversionRate', () {
    test('a live rate fills the field with no note', () {
      final fill = fillConversionRate(
        quote: FxQuote.live(Decimal.parse('0.0275')),
        current: empty,
      );
      expect(fill.text, '0.0275');
      expect(fill.note, isNull);
    });

    test('a live rate replaces a rate already shown', () {
      final fill = fillConversionRate(
        quote: FxQuote.live(Decimal.parse('0.03')),
        current: (text: '0.0275', note: null),
      );
      expect(fill.text, '0.03');
    });

    test('keeps the full rate, not four decimals', () {
      final fill = fillConversionRate(
        quote: FxQuote.live(Decimal.parse('0.004955')),
        current: empty,
      );
      expect(fill.text, '0.004955');
      final saved = fillConversionRate(
        quote: FxQuote.saved(Decimal.parse('0.0049553321'), savedAt),
        current: empty,
      );
      expect(saved.text, '0.0049553321');
    });

    test('a saved rate fills an empty field and says how old it is', () {
      final quote = FxQuote.saved(
        Decimal.parse('0.0275'),
        savedAt,
        FxRateFailure.offline,
      );
      final fill = fillConversionRate(quote: quote, current: empty);
      expect(fill.text, '0.0275');
      expect(fill.note?.savedAt, savedAt);
    });

    test('offline with no rate leaves the field empty, never 1', () {
      final fill = fillConversionRate(
        quote: const FxQuote.none(FxRateFailure.offline),
        current: empty,
      );
      expect(fill.text, isEmpty);
      expect(fill.note?.failure, FxRateFailure.offline);
    });

    test('a failed refresh keeps the rate already shown', () {
      const typed = (text: '0.0280', note: null);
      expect(
        fillConversionRate(
          quote: const FxQuote.none(FxRateFailure.offline),
          current: typed,
        ),
        typed,
      );
      expect(
        fillConversionRate(
          quote: FxQuote.saved(Decimal.parse('0.0275'), savedAt),
          current: typed,
        ),
        typed,
      );
    });
  });

  group('formatConversionRate', () {
    test('four decimals from 1 up, four significant digits below', () {
      expect(formatConversionRate(Decimal.parse('36.5')), '36.5000');
      expect(formatConversionRate(Decimal.parse('0.004955')), '0.004955');
      expect(formatConversionRate(Decimal.parse('0.0275')), '0.02750');
    });
  });

  group('convertAtRate', () {
    test('converts with the full rate and rounds to cents', () {
      // ¥150,000 at 0.004955 is £743.25, not £750.00 at a rounded 0.0050.
      expect(
        convertAtRate(Decimal.parse('150000'), Decimal.parse('0.004955')),
        Decimal.parse('743.25'),
      );
      expect(
        convertAtRate(Decimal.parse('100'), Decimal.parse('36.3636363636')),
        Decimal.parse('3636.36'),
      );
    });
  });
}
