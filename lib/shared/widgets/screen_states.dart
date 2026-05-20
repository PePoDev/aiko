import 'package:flutter/material.dart';

import '../../theme/aiko_colors.dart';

class AikoScreenState extends StatelessWidget {
  const AikoScreenState({
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  const AikoScreenState.loading({super.key})
    : title = 'Loading',
      message = 'Aiko is preparing your money view.',
      icon = Icons.hourglass_empty,
      action = const CircularProgressIndicator();

  const AikoScreenState.empty({
    required this.title,
    required this.message,
    this.action,
    super.key,
  }) : icon = Icons.inbox_outlined;

  const AikoScreenState.error({
    required this.title,
    required this.message,
    this.action,
    super.key,
  }) : icon = Icons.error_outline;

  const AikoScreenState.offline({super.key})
    : title = 'You are offline',
      message = 'Aiko will reconnect when the network is available.',
      icon = Icons.wifi_off,
      action = null;

  const AikoScreenState.locked({super.key})
    : title = 'Aiko is locked',
      message = 'Unlock to view your financial data.',
      icon = Icons.lock_outline,
      action = null;

  const AikoScreenState.permissionDenied({super.key})
    : title = 'Permission needed',
      message = 'Aiko needs permission before showing this information.',
      icon = Icons.privacy_tip_outlined,
      action = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                        color: theme.brightness == Brightness.dark
                            ? AikoColors.border
                            : AikoColors.mutedText,
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
