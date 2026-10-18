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

/// A page [Scaffold] with snack bars of its own, shown once and inside the
/// page.
///
/// The app's [ScaffoldMessenger] shows a snack bar on every [Scaffold] that
/// isn't inside another one. A page opened with `openAikoPage` in the
/// expanded layout is a dialog over the shell, so a snack bar it shows
/// through that messenger appears twice: in the dialog and behind it. Show
/// the page's own messages with `messengerKey.currentState` instead; they
/// appear over [body]. Messages meant to outlive the page (e.g. "Saved"
/// right before it closes) still go to the app's messenger.
class AikoPageScaffold extends StatelessWidget {
  const AikoPageScaffold({
    required this.messengerKey,
    required this.body,
    this.appBar,
    super.key,
  });

  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final PreferredSizeWidget? appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: ScaffoldMessenger(
        key: messengerKey,
        // Only hosts the page's snack bars, over the body.
        child: Scaffold(
          primary: false,
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: body,
        ),
      ),
    );
  }
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
