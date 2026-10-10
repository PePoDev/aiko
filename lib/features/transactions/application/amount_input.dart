import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';

final _amountPattern = RegExp(r'^[0-9,]*\.?[0-9]*$');

/// Parses an amount typed in the transaction form: digits with optional
/// thousands commas and one decimal point ("1,250.50", ".5", "12."). Returns
/// null for anything else or for an empty value.
Decimal? parseAmountInput(String raw) {
  final trimmed = raw.trim();
  if (!_amountPattern.hasMatch(trimmed)) return null;
  var cleaned = trimmed.replaceAll(',', '');
  if (cleaned.isEmpty || cleaned == '.') return null;
  if (cleaned.startsWith('.')) cleaned = '0$cleaned';
  if (cleaned.endsWith('.')) cleaned = '${cleaned}0';
  return Decimal.tryParse(cleaned);
}

/// Lets the amount field hold only digits, thousands commas before the
/// decimal point and a single decimal point; any other edit is rejected.
class AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _amountPattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
