import 'package:flutter/material.dart';

/// Primary form submit button. Renders a filled button with a
/// loading spinner when [busy] is true, preventing double-submits. Use this
/// instead of plain `FilledButton`s in any form that triggers an async save
/// (transaction, category, account, budget, profile, etc.).
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  /// Optional leading icon. Hidden while [busy] is true so the spinner
  /// doesn't compete for attention.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = busy ? null : onPressed;
    return FilledButton(
      onPressed: effectiveOnPressed,
      child: busy
          ? const SizedBox(
              key: ValueKey('submit-button-spinner'),
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              key: const ValueKey('submit-button-label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
    );
  }
}
