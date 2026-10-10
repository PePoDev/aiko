import 'package:decimal/decimal.dart';

final _groupedThousands = RegExp(r'^[-+]?\d{1,3}(,\d{3})+(\.\d+)?$');

/// Parses an amount typed into an account form: surrounding spaces are
/// ignored and thousands separators are accepted (`50,000` or `1,234.50`).
/// Commas anywhere else are not guessed at (`12,50` stays invalid rather than
/// becoming 1250). Null when empty or not a number.
Decimal? parseAccountAmountInput(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  if (_groupedThousands.hasMatch(text)) text = text.replaceAll(',', '');
  if (text.startsWith('+')) text = text.substring(1);
  return Decimal.tryParse(text);
}
