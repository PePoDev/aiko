import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          const FinanceCard(
            title: 'Profile and privacy',
            icon: Icons.privacy_tip_outlined,
            child: Column(
              children: [
                _SettingsRow(icon: Icons.person_outline, title: 'Profile'),
                Divider(),
                _SettingsRow(icon: Icons.lock_outline, title: 'Security'),
                Divider(),
                _SettingsRow(
                  icon: Icons.psychology_alt_outlined,
                  title: 'AI consent',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FinanceCard(
            title: 'Money workspace',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: AikoColors.analyticsTeal,
            child: Column(
              children: [
                const _SettingsRow(
                  icon: Icons.public,
                  title: 'Currency',
                  subtitle: 'Base currency and regional formats',
                ),
                const Divider(),
                _SettingsRow(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Budget alerts, bills, and reminders',
                  onTap: () => context.push('/notification-settings'),
                ),
                const Divider(),
                _SettingsRow(
                  icon: Icons.import_export,
                  title: 'Import, export, and backup',
                  subtitle: 'Move data in and out of Aiko',
                  onTap: () => context.push('/import-export-backup'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FinanceCard(
            title: 'Plan',
            icon: Icons.workspace_premium_outlined,
            accentColor: AikoColors.premiumPurple,
            child: _SettingsRow(
              icon: Icons.auto_awesome_outlined,
              title: 'Subscription plan',
              subtitle: 'Free, Premium, and Pro features',
              onTap: () => context.push('/subscription-plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
