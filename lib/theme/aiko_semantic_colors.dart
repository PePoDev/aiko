import 'package:flutter/material.dart';

/// Semantic color extensions for [ColorScheme].
///
/// These provide named access to Aiko's semantic palette values (success,
/// warning, analytics, AI purple) so feature widgets can pull them from
/// the theme instead of importing [AikoColors] directly.
///
/// Dark-mode variants are slightly lighter to maintain contrast on dark
/// surfaces while keeping the same semantic meaning.
extension AikoSemanticColors on ColorScheme {
  /// Savings progress, completed goals, positive deltas.
  Color get success => brightness == Brightness.light
      ? const Color(0xFF16A34A)
      : const Color(0xFF4ADE80);

  /// Bills, thresholds, upcoming due dates.
  Color get warning => brightness == Brightness.light
      ? const Color(0xFFF59E0B)
      : const Color(0xFFFBBF24);

  /// Overspending, failed payments, destructive actions.
  /// Falls back to the scheme's [error] color.
  Color get danger => error;

  /// Portfolio, reports, analysis surfaces.
  Color get analytics => brightness == Brightness.light
      ? const Color(0xFF0D9488)
      : const Color(0xFF2DD4BF);

  /// Aiko/AI moments, premium features, insight accents.
  /// Falls back to the scheme's [tertiary] color.
  Color get aiPurple => tertiary;
}
