import 'package:flutter/material.dart';

import 'aiko_colors.dart';

/// Status colours for text and small icons, per brightness. The brand fills
/// ([AikoColors.warningOrange], [AikoColors.successGreen],
/// [AikoColors.dangerRed]) stay for bars, chips and icons on tinted
/// backgrounds; words in a status colour use these so they stay readable
/// (at least 4.5:1) in light and dark mode.
@immutable
class AikoStatusColors extends ThemeExtension<AikoStatusColors> {
  const AikoStatusColors({
    required this.successText,
    required this.warningText,
    required this.dangerText,
  });

  final Color successText;
  final Color warningText;
  final Color dangerText;

  static const light = AikoStatusColors(
    successText: AikoColors.successText,
    warningText: AikoColors.warningText,
    dangerText: AikoColors.dangerText,
  );

  static const dark = AikoStatusColors(
    successText: AikoColors.successTextDark,
    warningText: AikoColors.warningTextDark,
    dangerText: AikoColors.dangerTextDark,
  );

  /// The set for the current theme (registered by `AikoTheme`).
  static AikoStatusColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AikoStatusColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// A readable text colour for [accent]: the status fills map to their text
  /// variants, every other colour is returned unchanged.
  Color textFor(Color accent) {
    if (accent == AikoColors.warningOrange) return warningText;
    if (accent == AikoColors.successGreen) return successText;
    if (accent == AikoColors.dangerRed) return dangerText;
    return accent;
  }

  @override
  AikoStatusColors copyWith({
    Color? successText,
    Color? warningText,
    Color? dangerText,
  }) {
    return AikoStatusColors(
      successText: successText ?? this.successText,
      warningText: warningText ?? this.warningText,
      dangerText: dangerText ?? this.dangerText,
    );
  }

  @override
  AikoStatusColors lerp(AikoStatusColors? other, double t) {
    if (other == null) return this;
    return AikoStatusColors(
      successText: Color.lerp(successText, other.successText, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
    );
  }
}
