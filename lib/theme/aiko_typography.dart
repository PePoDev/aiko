import 'package:flutter/material.dart';

class AikoTypography {
  const AikoTypography._();

  static const _headlineFont = 'Hanken Grotesk';
  static const _bodyFont = 'Manrope';

  static TextTheme textTheme(Color foreground) {
    TextStyle style({
      required double size,
      required FontWeight weight,
      required double height,
      String fontFamily = _bodyFont,
    }) {
      return TextStyle(
        color: foreground,
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: 0,
      );
    }

    return TextTheme(
      displayLarge: style(
        size: 48,
        weight: FontWeight.w700,
        height: 1.05,
        fontFamily: _headlineFont,
      ),
      headlineLarge: style(
        size: 36,
        weight: FontWeight.w700,
        height: 1.08,
        fontFamily: _headlineFont,
      ),
      headlineMedium: style(
        size: 28,
        weight: FontWeight.w700,
        height: 1.15,
        fontFamily: _headlineFont,
      ),
      titleLarge: style(
        size: 20,
        weight: FontWeight.w700,
        height: 1.25,
        fontFamily: _headlineFont,
      ),
      titleMedium: style(size: 16, weight: FontWeight.w700, height: 1.3),
      titleSmall: style(size: 14, weight: FontWeight.w700, height: 1.3),
      bodyLarge: style(size: 16, weight: FontWeight.w400, height: 1.45),
      bodyMedium: style(size: 14, weight: FontWeight.w400, height: 1.45),
      bodySmall: style(size: 12, weight: FontWeight.w500, height: 1.35),
      labelLarge: style(size: 14, weight: FontWeight.w700, height: 1.2),
      labelMedium: style(size: 12, weight: FontWeight.w700, height: 1.2),
      labelSmall: style(size: 11, weight: FontWeight.w700, height: 1.2),
    );
  }

  static TextStyle mutedLabel(Color foreground) {
    return TextStyle(
      color: foreground,
      fontFamily: _bodyFont,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 0,
    );
  }
}
