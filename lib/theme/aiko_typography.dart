import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AikoTypography {
  const AikoTypography._();

  /// Headline text style using Hanken Grotesk (geometric, friendly).
  static TextStyle _headline({
    required Color color,
    required double size,
    required FontWeight weight,
    required double height,
  }) {
    return GoogleFonts.hankenGrotesk(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
    );
  }

  /// Body / label text style using Manrope (softer, readable).
  static TextStyle _body({
    required Color color,
    required double size,
    required FontWeight weight,
    required double height,
  }) {
    return GoogleFonts.manrope(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
    );
  }

  static TextTheme textTheme(Color foreground) {
    return TextTheme(
      displayLarge: _headline(
        color: foreground,
        size: 48,
        weight: FontWeight.w700,
        height: 1.05,
      ),
      headlineLarge: _headline(
        color: foreground,
        size: 36,
        weight: FontWeight.w700,
        height: 1.08,
      ),
      headlineMedium: _headline(
        color: foreground,
        size: 28,
        weight: FontWeight.w700,
        height: 1.15,
      ),
      titleLarge: _headline(
        color: foreground,
        size: 20,
        weight: FontWeight.w700,
        height: 1.25,
      ),
      titleMedium: _body(
        color: foreground,
        size: 16,
        weight: FontWeight.w700,
        height: 1.3,
      ),
      titleSmall: _body(
        color: foreground,
        size: 14,
        weight: FontWeight.w700,
        height: 1.3,
      ),
      bodyLarge: _body(
        color: foreground,
        size: 16,
        weight: FontWeight.w400,
        height: 1.45,
      ),
      bodyMedium: _body(
        color: foreground,
        size: 14,
        weight: FontWeight.w400,
        height: 1.45,
      ),
      bodySmall: _body(
        color: foreground,
        size: 12,
        weight: FontWeight.w500,
        height: 1.35,
      ),
      labelLarge: _body(
        color: foreground,
        size: 14,
        weight: FontWeight.w700,
        height: 1.2,
      ),
      labelMedium: _body(
        color: foreground,
        size: 12,
        weight: FontWeight.w700,
        height: 1.2,
      ),
      labelSmall: _body(
        color: foreground,
        size: 11,
        weight: FontWeight.w700,
        height: 1.2,
      ),
    );
  }

  static TextStyle mutedLabel(Color foreground) {
    return GoogleFonts.manrope(
      color: foreground,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 0,
    );
  }
}
