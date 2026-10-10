import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

class AikoScreenState extends StatelessWidget {
  const AikoScreenState({
    required String this.title,
    required String this.message,
    this.icon = Icons.info_outline,
    this.action,
    super.key,
  });

  /// Null only for [AikoScreenState.loading], which uses localized defaults.
  final String? title;
  final String? message;
  final IconData icon;
  final Widget? action;

  const AikoScreenState.loading({super.key})
    : title = null,
      message = null,
      icon = Icons.hourglass_empty,
      action = const CircularProgressIndicator();

  const AikoScreenState.empty({
    required String this.title,
    required String this.message,
    this.action,
    super.key,
  }) : icon = Icons.inbox_outlined;

  const AikoScreenState.error({
    required String this.title,
    required String this.message,
    this.action,
    super.key,
  }) : icon = Icons.error_outline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = this.title ?? context.l10n.screenStateLoadingTitle;
    final message = this.message ?? context.l10n.screenStateLoadingMessage;

    return Center(
      child: Semantics(
        label: '$title. $message',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 28, color: colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(height: 16),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
