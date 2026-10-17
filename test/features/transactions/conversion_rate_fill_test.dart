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
      expect(fill.text, '0.0300');
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
}
