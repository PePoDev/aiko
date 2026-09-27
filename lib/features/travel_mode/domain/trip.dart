import '../../../core/money/money.dart';

class Trip {
  const Trip({
    required this.name,
    required this.homeCurrency,
    required this.localCurrency,
    required this.budget,
    this.foreignFees = const <Money>[],
  });

  final String name;
  final String homeCurrency;
  final String localCurrency;
  final Money budget;
  final List<Money> foreignFees;

  Map<String, dynamic> toJson() => {
    'name': name,
    'homeCurrency': homeCurrency,
    'localCurrency': localCurrency,
    'budget': budget.toJson(),
    'foreignFees': foreignFees.map((fee) => fee.toJson()).toList(),
  };

  factory Trip.fromJson(Map<String, dynamic> json) {
    Money money(Map value) =>
        Money.parse(value['amount'] as String, value['currency'] as String);
    return Trip(
      name: json['name'] as String,
      homeCurrency: json['homeCurrency'] as String,
      localCurrency: json['localCurrency'] as String,
      budget: money(json['budget'] as Map),
      foreignFees: (json['foreignFees'] as List)
          .map((fee) => money(fee as Map))
          .toList(),
    );
  }

  Trip copyWith({
    String? name,
    String? homeCurrency,
    String? localCurrency,
    Money? budget,
    List<Money>? foreignFees,
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
