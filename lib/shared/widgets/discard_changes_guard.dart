import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import '../../l10n/l10n.dart';

/// Asks "Discard changes?" before a form with unsaved input closes. Covers
/// every way out that goes through `Navigator.maybePop`: the app-bar back or
/// close button, the system back gesture, Escape, and a dialog barrier.
///
/// Wrap the form's root widget and pass whether it has unsaved input:
///
/// ```dart
/// return AikoDiscardChangesGuard(
///   hasUnsavedChanges: _isDirty,
///   child: Scaffold(...),
/// );
/// ```
///
/// Closing in code after saving (`Navigator.pop`, `context.pop`) is never
/// blocked, so a Save button can pop right away.
class AikoDiscardChangesGuard extends StatelessWidget {
  const AikoDiscardChangesGuard({
    required this.hasUnsavedChanges,
    required this.child,
    super.key,
  });

  final bool hasUnsavedChanges;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (!await confirmDiscardChanges(context)) return;
        if (navigator.canPop()) {
          navigator.pop(result);
        } else {
          // The first page: back would have left the app.
          await SystemNavigator.pop();
        }
      },
      child: child,
    );
  }
}

/// Shows the "Discard changes?" dialog. True when the user chose Discard.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return AlertDialog(
        title: Text(l10n.discardChangesTitle),
        content: Text(l10n.discardChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.discardChangesKeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.discardChangesDiscard),
          ),
        ],
      );
    },
  );
  return discard ?? false;
}
