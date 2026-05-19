import '../../../core/money/currency_conversion_service.dart';
import '../../../core/money/money.dart';
import '../domain/asset.dart';

class NetWorthService {
  const NetWorthService({
    this.currencyConversion = const CurrencyConversionService(),
  });

  final CurrencyConversionService currencyConversion;

  Money calculate(List<Asset> assets, String currency) {
    var total = Money.zero(currency);
    for (final asset in assets) {
      final value = currencyConversion.convert(asset.value, currency);
      total = asset.isLiability ? total - value : total + value;
    }
    return total;
  }
}
