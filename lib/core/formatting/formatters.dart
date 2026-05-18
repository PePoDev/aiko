import '../money/money.dart';

class AikoFormatters {
  const AikoFormatters._();

  static String money(Money value) => value.format();

  static String percent(num value) => '${value.toStringAsFixed(0)}%';
}
