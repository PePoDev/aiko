import 'package:flutter/material.dart';

/// Result of a [showDiscardChangesDialog] — the user explicitly chose to
/// keep editing or discard their work.
enum DiscardChangesChoice { keepEditing, discard }

/// Asks the user to confirm discarding in-flight form changes. The
/// standard pattern: form screens wrap their body in a [PopScope] that calls
/// this when the user swipes back, taps the close icon, or any other
/// navigation gesture that would leave the route.
///
/// Strings are hard-coded English today;
/// call sites that already have a screen-local `AppLocalizations.of(context)`
/// can pass overrides via the parameters, or wrap the call in a localised
/// version of this dialog.
Future<DiscardChangesChoice?> showDiscardChangesDialog(
  BuildContext context, {
  String title = 'Discard changes?',
  String body = 'Your edits have not been saved. Leave this screen anyway?',
  String keepEditingLabel = 'Keep editing',
  String discardLabel = 'Discard',
}) {
  return showDialog<DiscardChangesChoice>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              DiscardChangesChoice.keepEditing,
            ),
            child: Text(keepEditingLabel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(
              DiscardChangesChoice.discard,
            ),
            child: Text(discardLabel),
          ),
        ],
      );
    },
  );
}
