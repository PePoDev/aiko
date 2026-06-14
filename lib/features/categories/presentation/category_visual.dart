import 'package:flutter/material.dart';

import '../../../theme/aiko_colors.dart';

/// Maps a string icon key (used in domain/brick models) to a Material icon.
IconData aikoCategoryIcon(String name) {
  switch (name) {
    case 'food':
    case 'groceries':
    case 'dining':
    case 'lunch':
    case 'dinner':
      return Icons.restaurant_outlined;
    case 'dessert':
      return Icons.icecream_outlined;
    case 'drink':
    case 'bubble_tea':
      return Icons.local_bar_outlined;
    case 'snack':
      return Icons.bakery_dining_outlined;
    case 'housing':
    case 'home':
    case 'rent':
      return Icons.home_outlined;
    case 'travel':
    case 'flights':
      return Icons.flight_outlined;
    case 'hotel':
    case 'accommodation':
      return Icons.hotel_outlined;
    case 'coffee':
      return Icons.coffee_outlined;
    case 'shopping':
    case 'furniture':
      return Icons.shopping_bag_outlined;
    case 'savings':
    case 'savings_contribution':
      return Icons.savings_outlined;
    case 'investing':
    case 'investment':
    case 'capital_gains':
      return Icons.trending_up_outlined;
    case 'gym':
    case 'fitness':
      return Icons.fitness_center_outlined;
    case 'salary':
      return Icons.attach_money_outlined;
    case 'entertainment':
    case 'movie':
    case 'movies':
      return Icons.movie_outlined;
    case 'game':
    case 'games':
      return Icons.sports_esports_outlined;
    case 'music':
      return Icons.music_note_outlined;
    case 'concert':
    case 'concerts':
      return Icons.confirmation_number_outlined;
    case 'hobby':
    case 'hobbies':
      return Icons.palette_outlined;
    case 'gift':
    case 'gifts':
      return Icons.card_giftcard_outlined;
    case 'donation':
    case 'donations':
      return Icons.volunteer_activism_outlined;
    case 'work':
    case 'business':
      return Icons.work_outline;
    case 'refund':
    case 'refunds':
      return Icons.replay_outlined;
    case 'transport':
    case 'tolls':
      return Icons.directions_bus_outlined;
    case 'taxi':
    case 'rideshare':
      return Icons.local_taxi_outlined;
    case 'parking':
      return Icons.local_parking_outlined;
    case 'fuel':
      return Icons.local_gas_station_outlined;
    case 'maintenance':
    case 'vehicle':
      return Icons.build_outlined;
    case 'utilities':
      return Icons.bolt_outlined;
    case 'phone':
      return Icons.phone_android_outlined;
    case 'internet':
      return Icons.wifi_outlined;
    case 'subscriptions':
      return Icons.subscriptions_outlined;
    case 'health':
    case 'pharmacy':
    case 'medicine':
      return Icons.health_and_safety_outlined;
    case 'dental':
      return Icons.medical_information_outlined;
    case 'insurance':
      return Icons.verified_user_outlined;
    case 'education':
    case 'courses':
      return Icons.school_outlined;
    case 'book':
    case 'books':
      return Icons.menu_book_outlined;
    case 'clothing':
      return Icons.checkroom_outlined;
    case 'electronics':
      return Icons.devices_outlined;
    case 'personal_care':
    case 'spa':
      return Icons.spa_outlined;
    case 'childcare':
      return Icons.child_care_outlined;
    case 'pet':
    case 'pets':
      return Icons.pets_outlined;
    case 'fee':
    case 'fees':
    case 'foreign_fees':
      return Icons.receipt_long_outlined;
    case 'tax':
    case 'taxes':
      return Icons.request_quote_outlined;
    case 'loan':
    case 'loans':
    case 'loan_interest':
      return Icons.account_balance_outlined;
    case 'credit_card':
    case 'credit_cards':
      return Icons.credit_card_outlined;
    case 'water':
      return Icons.water_drop_outlined;
    case 'electricity':
      return Icons.bolt_outlined;
    case 'food_delivery':
      return Icons.delivery_dining_outlined;
    case 'public_transport':
      return Icons.directions_transit_outlined;
    case 'jewelry':
      return Icons.diamond_outlined;
    case 'shoes':
    case 'sneakers':
      return Icons.hiking_outlined;
    case 'workshop':
      return Icons.handyman_outlined;
    case 'doctor':
      return Icons.medical_services_outlined;
    case 'medicine_treatment':
      return Icons.medical_services_outlined;
    case 'life_insurance':
      return Icons.shield_outlined;
    case 'boxing':
    case 'gym_boxing':
      return Icons.sports_mma_outlined;
    case 'fitness_class':
      return Icons.sports_gymnastics_outlined;
    case 'fitness_equipment':
      return Icons.fitness_center_outlined;
    case 'supplements':
      return Icons.medication_outlined;
    case 'social_security':
      return Icons.badge_outlined;
    case 'category':
    default:
      return Icons.category_outlined;
  }
}

/// Parses a `#RRGGBB` hex color into a fully-opaque Color. Falls back to the
/// primary brand blue on invalid input.
Color aikoHexColor(String hex) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return AikoColors.primaryBlue;
  }
}

/// Reusable color presets exposed in the category and group editors.
const List<Map<String, String>> aikoCategoryColorPresets = [
  {'name': 'Blue', 'hex': '#3B82F6'},
  {'name': 'Green', 'hex': '#16A34A'},
  {'name': 'Orange', 'hex': '#F59E0B'},
  {'name': 'Red', 'hex': '#DC2626'},
  {'name': 'Purple', 'hex': '#7C3AED'},
  {'name': 'Teal', 'hex': '#0D9488'},
  {'name': 'Pink', 'hex': '#EC4899'},
  {'name': 'Indigo', 'hex': '#6366F1'},
];

/// Reusable icon presets exposed in the category and group editors.
final List<MapEntry<String, IconData>> aikoCategoryIconPresets = [
  const MapEntry('category', Icons.category_outlined),
  const MapEntry('food', Icons.restaurant_outlined),
  const MapEntry('coffee', Icons.coffee_outlined),
  const MapEntry('dessert', Icons.icecream_outlined),
  const MapEntry('drink', Icons.local_bar_outlined),
  const MapEntry('snack', Icons.bakery_dining_outlined),
  const MapEntry('housing', Icons.home_outlined),
  const MapEntry('furniture', Icons.shopping_bag_outlined),
  const MapEntry('transport', Icons.directions_bus_outlined),
  const MapEntry('taxi', Icons.local_taxi_outlined),
  const MapEntry('parking', Icons.local_parking_outlined),
  const MapEntry('fuel', Icons.local_gas_station_outlined),
  const MapEntry('maintenance', Icons.build_outlined),
  const MapEntry('travel', Icons.flight_outlined),
  const MapEntry('hotel', Icons.hotel_outlined),
  const MapEntry('shopping', Icons.shopping_bag_outlined),
  const MapEntry('clothing', Icons.checkroom_outlined),
  const MapEntry('electronics', Icons.devices_outlined),
  const MapEntry('personal_care', Icons.spa_outlined),
  const MapEntry('utilities', Icons.bolt_outlined),
  const MapEntry('phone', Icons.phone_android_outlined),
  const MapEntry('internet', Icons.wifi_outlined),
  const MapEntry('subscriptions', Icons.subscriptions_outlined),
  const MapEntry('health', Icons.health_and_safety_outlined),
  const MapEntry('medicine', Icons.health_and_safety_outlined),
  const MapEntry('dental', Icons.medical_information_outlined),
  const MapEntry('gym', Icons.fitness_center_outlined),
  const MapEntry('insurance', Icons.verified_user_outlined),
  const MapEntry('education', Icons.school_outlined),
  const MapEntry('book', Icons.menu_book_outlined),
  const MapEntry('savings', Icons.savings_outlined),
  const MapEntry('investing', Icons.trending_up_outlined),
  const MapEntry('salary', Icons.attach_money_outlined),
  const MapEntry('fee', Icons.receipt_long_outlined),
  const MapEntry('tax', Icons.request_quote_outlined),
  const MapEntry('loan', Icons.account_balance_outlined),
  const MapEntry('credit_card', Icons.credit_card_outlined),
  const MapEntry('entertainment', Icons.movie_outlined),
  const MapEntry('music', Icons.music_note_outlined),
  const MapEntry('game', Icons.sports_esports_outlined),
  const MapEntry('concert', Icons.confirmation_number_outlined),
  const MapEntry('hobby', Icons.palette_outlined),
  const MapEntry('gift', Icons.card_giftcard_outlined),
  const MapEntry('donation', Icons.volunteer_activism_outlined),
  const MapEntry('childcare', Icons.child_care_outlined),
  const MapEntry('pet', Icons.pets_outlined),
  const MapEntry('business', Icons.work_outline),
  const MapEntry('water', Icons.water_drop_outlined),
  const MapEntry('electricity', Icons.bolt_outlined),
  const MapEntry('food_delivery', Icons.delivery_dining_outlined),
  const MapEntry('public_transport', Icons.directions_transit_outlined),
  const MapEntry('jewelry', Icons.diamond_outlined),
  const MapEntry('shoes', Icons.hiking_outlined),
  const MapEntry('workshop', Icons.handyman_outlined),
  const MapEntry('doctor', Icons.medical_services_outlined),
  const MapEntry('medicine_treatment', Icons.medical_services_outlined),
  const MapEntry('life_insurance', Icons.shield_outlined),
  const MapEntry('boxing', Icons.sports_mma_outlined),
  const MapEntry('fitness_class', Icons.sports_gymnastics_outlined),
  const MapEntry('fitness_equipment', Icons.fitness_center_outlined),
  const MapEntry('supplements', Icons.medication_outlined),
  const MapEntry('social_security', Icons.badge_outlined),
  const MapEntry('loan_interest', Icons.account_balance_outlined),
];
