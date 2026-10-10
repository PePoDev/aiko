import 'package:aiko/features/transactions/application/amount_input.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAmountInput', () {
    test('accepts thousands commas and a decimal point', () {
      expect(parseAmountInput('1,250.00'), Decimal.parse('1250'));
      expect(parseAmountInput('12,345,678.9'), Decimal.parse('12345678.9'));
      expect(parseAmountInput(' 65 '), Decimal.parse('65'));
    });

    test('accepts a leading or trailing decimal point', () {
      expect(parseAmountInput('.5'), Decimal.parse('0.5'));
      expect(parseAmountInput('12.'), Decimal.parse('12'));
    });

    test('rejects empty and non-numeric input', () {
      expect(parseAmountInput(''), isNull);
      expect(parseAmountInput('.'), isNull);
      expect(parseAmountInput(','), isNull);
      expect(parseAmountInput('1.2.3'), isNull);
      expect(parseAmountInput('-5'), isNull);
      expect(parseAmountInput('12a'), isNull);
      expect(parseAmountInput('1.000,50'), isNull);
    });
  });

  group('AmountInputFormatter', () {
    final formatter = AmountInputFormatter();
    TextEditingValue edit(String from, String to) => formatter.formatEditUpdate(
      TextEditingValue(text: from),
      TextEditingValue(text: to),
    );

    test('keeps digits, commas and one decimal point', () {
      expect(edit('1,25', '1,250').text, '1,250');
      expect(edit('1,250', '1,250.').text, '1,250.');
      expect(edit('1,250.', '1,250.5').text, '1,250.5');
    });

    test('rejects letters, a second point and commas after the point', () {
      expect(edit('12', '12a').text, '12');
      expect(edit('1.5', '1.5.').text, '1.5');
      expect(edit('1.5', '1.5,').text, '1.5');
      expect(edit('12', '-12').text, '12');
    });
  });
}
