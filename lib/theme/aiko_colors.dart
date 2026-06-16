import 'package:flutter/material.dart';

class AikoColors {
  const AikoColors._();

  static const white = Color(0xFFFFFFFF);

  /// The brand's primary blue in hex form. The single source of truth for the
  /// primary colour across theme and data defaults. Pair with
  /// [primaryBlue] (a `Color` of the same value) when Flutter needs a
  /// `Color`; use [kAikoPrimaryColorHex] when a `String` is needed (e.g.
  /// persisted on a `Category` row in offline storage).
  static const kAikoPrimaryColorHex = '#3B82F6';
  static const primaryBlue = Color(0xFF3B82F6);
  static const deepBlue = Color(0xFF1D4ED8);
  static const softBlue = Color(0xFF93C5FD);
  static const paleBlue = Color(0xFFEFF6FF);
  static const darkNavy = Color(0xFF0F172A);
  static const appBackground = Color(0xFFD8E0F5);
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
}
