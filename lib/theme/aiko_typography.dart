import 'package:flutter/material.dart';

class AikoTypography {
  const AikoTypography._();

  static TextTheme textTheme(Color foreground) {
    return TextTheme(
      headlineMedium: TextStyle(
        color: foreground,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: foreground,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: foreground,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: foreground, fontSize: 16),
      bodyMedium: TextStyle(color: foreground, fontSize: 14),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }
}
