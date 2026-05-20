import 'package:flutter/material.dart';

class AikoColors {
  const AikoColors._();

  static const white = Color(0xFFFFFFFF);
  static const primaryBlue = Color(0xFF3B82F6);
  static const deepBlue = Color(0xFF1D4ED8);
  static const softBlue = Color(0xFF93C5FD);
  static const paleBlue = Color(0xFFEFF6FF);
  static const darkNavy = Color(0xFF0F172A);
  static const appBackground = Color(0xFFD8E0F5);
  static const appBackgroundLight = Color(0xFFF6F8FF);
  static const surfacePanel = Color(0xFFEEF2FF);
  static const surfacePanelStrong = Color(0xFFE3E9FF);
  static const surfacePanelDark = Color(0xFF121C31);
  static const surfacePanelDarkStrong = Color(0xFF1B2740);
  static const border = Color(0xFFBAC3D6);
  static const borderSubtle = Color(0xFFDCE4F8);
  static const mutedText = Color(0xFF778196);
  static const neutralInk = Color(0xFF293348);
  static const successGreen = Color(0xFF16A34A);
  static const warningOrange = Color(0xFFF59E0B);
  static const dangerRed = Color(0xFFDC2626);
  static const premiumPurple = Color(0xFF7C3AED);
  static const analyticsTeal = Color(0xFF0D9488);

  static const primaryRamp = <Color>[
    Color(0xFF071426),
    Color(0xFF0B356F),
    Color(0xFF0C4A9A),
    Color(0xFF0B5DBD),
    Color(0xFF1D74E8),
    primaryBlue,
    Color(0xFF75A4F5),
    Color(0xFFA5C4F6),
    Color(0xFFD8E5FF),
    white,
  ];

  static const secondaryRamp = <Color>[
    Color(0xFF071426),
    Color(0xFF0B2A7A),
    Color(0xFF073AA8),
    deepBlue,
    Color(0xFF4268EA),
    Color(0xFF6385F0),
    Color(0xFF8AA4F5),
    Color(0xFFAFC0F8),
    Color(0xFFDCE5FF),
    white,
  ];

  static const tertiaryRamp = <Color>[
    Color(0xFF071426),
    Color(0xFF240052),
    Color(0xFF3B0785),
    Color(0xFF5B0BC0),
    Color(0xFF6D28D9),
    premiumPurple,
    Color(0xFF9B67F2),
    Color(0xFFB894F5),
    Color(0xFFDCCBFF),
    white,
  ];

  static const neutralRamp = <Color>[
    Color(0xFF071426),
    darkNavy,
    neutralInk,
    Color(0xFF414B60),
    Color(0xFF5B6578),
    mutedText,
    Color(0xFF9BA4B8),
    border,
    borderSubtle,
    white,
  ];
}
