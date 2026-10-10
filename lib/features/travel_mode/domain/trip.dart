import '../../../core/money/money.dart';

/// A charge logged during a trip, in the trip's local or home currency, with
/// the merchant or details the traveller typed (optional).
class TravelFee {
  const TravelFee({required this.amount, this.merchant});

  final Money amount;
  final String? merchant;

  String get currency => amount.currency;

  /// Stored as the plain money JSON plus `merchant`, so fees saved before
  /// merchants were kept still load.
  Map<String, dynamic> toJson() => {
    ...amount.toJson(),
    if (merchant != null) 'merchant': merchant,
  };

  factory TravelFee.fromJson(Map<dynamic, dynamic> json) {
    final merchant = (json['merchant'] as String?)?.trim();
    return TravelFee(
      amount: Money.parse(json['amount'] as String, json['currency'] as String),
      merchant: merchant == null || merchant.isEmpty ? null : merchant,
    );
  }
}

class Trip {
  const Trip({
    required this.name,
    required this.homeCurrency,
    required this.localCurrency,
    required this.budget,
    this.foreignFees = const <TravelFee>[],
  });

  final String name;
  final String homeCurrency;
  final String localCurrency;
  final Money budget;
  final List<TravelFee> foreignFees;

  Map<String, dynamic> toJson() => {
    'name': name,
    'homeCurrency': homeCurrency,
    'localCurrency': localCurrency,
    'budget': budget.toJson(),
    'foreignFees': foreignFees.map((fee) => fee.toJson()).toList(),
  };

  factory Trip.fromJson(Map<String, dynamic> json) {
    final budget = json['budget'] as Map;
    return Trip(
      name: json['name'] as String,
      homeCurrency: json['homeCurrency'] as String,
      localCurrency: json['localCurrency'] as String,
      budget: Money.parse(
        budget['amount'] as String,
        budget['currency'] as String,
      ),
      foreignFees: (json['foreignFees'] as List)
          .map((fee) => TravelFee.fromJson(fee as Map))
          .toList(),
    );
  }

  Trip copyWith({
    String? name,
    String? homeCurrency,
    String? localCurrency,
    Money? budget,
    List<TravelFee>? foreignFees,
  }) {
    return Trip(
      name: name ?? this.name,
      homeCurrency: homeCurrency ?? this.homeCurrency,
      localCurrency: localCurrency ?? this.localCurrency,
      budget: budget ?? this.budget,
      foreignFees: foreignFees ?? this.foreignFees,
    );
  }
}
