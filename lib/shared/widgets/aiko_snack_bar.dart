import 'package:flutter/material.dart';

import '../../theme/aiko_status_colors.dart';

/// What a snack bar reports; picks its icon.
enum AikoSnackTone { info, success, warning, error }

/// A snack bar on the theme's neutral background (readable in light and dark
/// mode) with an icon for [tone], instead of white text on a coloured
/// background. Use it with a messenger captured before an `await`:
/// `messenger.showSnackBar(aikoSnackBar(l10n.saved, tone: AikoSnackTone.success))`.
SnackBar aikoSnackBar(
  String message, {
  AikoSnackTone tone = AikoSnackTone.info,
  SnackBarAction? action,
}) {
  // The theme's snack bar background is dark in both themes, so the icons
  // use the dark-mode status colours.
  const colors = AikoStatusColors.dark;
  final (IconData? icon, Color? color) = switch (tone) {
    AikoSnackTone.info => (null, null),
    AikoSnackTone.success => (Icons.check_circle_outline, colors.successText),
    AikoSnackTone.warning => (Icons.warning_amber_rounded, colors.warningText),
    AikoSnackTone.error => (Icons.error_outline, colors.dangerText),
  };
  return SnackBar(
    action: action,
    content: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
        ],
        Expanded(child: Text(message)),
      ],
    ),
  );
}

/// Shows [aikoSnackBar] in the nearest [ScaffoldMessenger].
void showAikoSnackBar(
  BuildContext context,
  String message, {
  AikoSnackTone tone = AikoSnackTone.info,
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(aikoSnackBar(message, tone: tone, action: action));
}
