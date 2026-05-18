import 'package:flutter/material.dart';

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
    return Center(
      child: Semantics(
        label: '$title. $message',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
  }
}
