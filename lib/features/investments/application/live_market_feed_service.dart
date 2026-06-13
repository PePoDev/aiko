import '../../../core/money/money.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import 'package:decimal/decimal.dart';

class LiveMarketFeedService {
  const LiveMarketFeedService();

  Future<Money> fetchLivePrice(String symbol, {String currency = 'USD'}) async {
    final client = AikoSupabase.tryClient();
    if (client == null) {
      throw StateError('Supabase is not configured; cannot fetch live prices.');
    }

    final response = await client.functions.invoke(
      'market-feed',
      body: {'symbol': symbol, 'currency': currency},
    );
    final data = response.data as Map<String, dynamic>;
    final priceVal = double.parse(data['price'].toString());
    return Money(
      amount: Decimal.parse(priceVal.toStringAsFixed(2)),
      currency: currency,
    );
  }
}
