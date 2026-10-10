import 'package:flutter/material.dart';

import 'aiko_breakpoints.dart';

/// Opens a modal panel: a bottom sheet in the compact layout, a centered dialog
/// in the expanded (web/desktop) layout. Use it instead of
/// `showModalBottomSheet` so every panel works on both
/// (`test/shared/layout/adaptive_presentation_guard_test.dart` enforces this).
Future<T?> showAikoSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool showDragHandle = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  double maxDialogWidth = 560,
}) {
  if (AikoBreakpoints.isExpanded(context)) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => _AikoDialogFrame(
        maxWidth: maxDialogWidth,
        maxHeightFactor: 0.85,
        backgroundColor: backgroundColor,
        // Room the drag handle would take on a bottom sheet.
        child: showDragHandle
            ? Padding(
                padding: const EdgeInsets.only(top: 16),
                child: builder(dialogContext),
              )
            : builder(dialogContext),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    shape: shape,
  );
}

/// Opens a page: a full-screen route in the compact layout, a large dialog over
/// the current screen in the expanded layout (keeping the sidebar and context
/// in view). Use it instead of `Navigator.push(MaterialPageRoute(...))`.
/// The page pops itself as usual; results are returned in both layouts.
Future<T?> openAikoPage<T>(
  BuildContext context,
  Widget page, {
  bool rootNavigator = false,
  double maxDialogWidth = 760,
}) {
  if (AikoBreakpoints.isExpanded(context)) {
    return showDialog<T>(
      context: context,
      builder: (_) => _AikoDialogFrame(
        maxWidth: maxDialogWidth,
        maxHeightFactor: 0.92,
        fillHeight: true,
        // The page's own back button closes the dialog; show it as a close.
        child: ActionIconTheme(
          data: ActionIconThemeData(
            backButtonIconBuilder: (_) => const Icon(Icons.close),
          ),
          child: page,
        ),
      ),
    );
  }
  return Navigator.of(
    context,
    rootNavigator: rootNavigator,
  ).push<T>(MaterialPageRoute<T>(builder: (_) => page));
}

class _AikoDialogFrame extends StatelessWidget {
  const _AikoDialogFrame({
    required this.maxWidth,
    required this.maxHeightFactor,
    required this.child,
    this.backgroundColor,
    this.fillHeight = false,
  });

  final double maxWidth;
  final double maxHeightFactor;
  final Color? backgroundColor;
  final bool fillHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;
    return Dialog(
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: maxWidth,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          minHeight: fillHeight ? maxHeight : 0,
        ),
        child: child,
      ),
    );
  }
}

/// Drag handle for panels opened with [showAikoSheet]. Shown on bottom sheets;
/// hidden in the expanded layout, where the panel is a dialog.
class AikoSheetHandle extends StatelessWidget {
  const AikoSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    if (AikoBreakpoints.isExpanded(context)) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: Container(
          width: 48,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outline,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
