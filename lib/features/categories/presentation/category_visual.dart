import 'package:flutter/material.dart';

import '../../../theme/aiko_colors.dart';

/// Maps a string icon key (used in domain/brick models) to a Material icon.
IconData aikoCategoryIcon(String name) {
  switch (name) {
    case 'food':
    case 'groceries':
    case 'dining':
      return Icons.restaurant_outlined;
    case 'housing':
    case 'home':
    case 'rent':
      return Icons.home_outlined;
    case 'travel':
      return Icons.flight_outlined;
    case 'coffee':
      return Icons.coffee_outlined;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'savings':
      return Icons.savings_outlined;
    case 'investing':
    case 'investment':
      return Icons.trending_up_outlined;
    case 'gym':
      return Icons.fitness_center_outlined;
    case 'salary':
      return Icons.attach_money_outlined;
    case 'entertainment':
      return Icons.movie_outlined;
    case 'gift':
      return Icons.card_giftcard_outlined;
    case 'work':
    case 'business':
      return Icons.work_outline;
    case 'refund':
    case 'refunds':
      return Icons.replay_outlined;
    case 'transport':
      return Icons.directions_bus_outlined;
    case 'fuel':
      return Icons.local_gas_station_outlined;
    case 'utilities':
      return Icons.bolt_outlined;
    case 'phone':
      return Icons.phone_android_outlined;
    case 'internet':
      return Icons.wifi_outlined;
    case 'subscriptions':
      return Icons.subscriptions_outlined;
    case 'health':
      return Icons.health_and_safety_outlined;
    case 'insurance':
      return Icons.verified_user_outlined;
    case 'education':
      return Icons.school_outlined;
    case 'fee':
    case 'fees':
      return Icons.receipt_long_outlined;
    case 'tax':
    case 'taxes':
      return Icons.request_quote_outlined;
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
  const MapEntry('housing', Icons.home_outlined),
  const MapEntry('transport', Icons.directions_bus_outlined),
  const MapEntry('fuel', Icons.local_gas_station_outlined),
  const MapEntry('travel', Icons.flight_outlined),
  const MapEntry('coffee', Icons.coffee_outlined),
  const MapEntry('shopping', Icons.shopping_bag_outlined),
  const MapEntry('utilities', Icons.bolt_outlined),
  const MapEntry('phone', Icons.phone_android_outlined),
  const MapEntry('internet', Icons.wifi_outlined),
  const MapEntry('subscriptions', Icons.subscriptions_outlined),
  const MapEntry('health', Icons.health_and_safety_outlined),
  const MapEntry('insurance', Icons.verified_user_outlined),
  const MapEntry('education', Icons.school_outlined),
  const MapEntry('savings', Icons.savings_outlined),
  const MapEntry('investing', Icons.trending_up_outlined),
  const MapEntry('gym', Icons.fitness_center_outlined),
  const MapEntry('salary', Icons.attach_money_outlined),
  const MapEntry('fee', Icons.receipt_long_outlined),
  const MapEntry('tax', Icons.request_quote_outlined),
  const MapEntry('entertainment', Icons.movie_outlined),
  const MapEntry('gift', Icons.card_giftcard_outlined),
  const MapEntry('business', Icons.work_outline),
];
