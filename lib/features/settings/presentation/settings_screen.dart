import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/locale_controller.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/profile.dart';
import '../../../core/security/persistent_secure_app_lock_service.dart';
import '../../../core/security/biometric_auth_adapter.dart';
import '../../../core/security/app_lock_service.dart';
import '../../../core/storage/secure_storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _authRepository = AuthRepository();
  var _isSigningOut = false;
  var _isDeleting = false;

  final _lockService = PersistentSecureAppLockService(
    storage: FlutterSecureStorageService(),
  );
  final _bioAdapter = LocalBiometricAuthAdapter();

  Future<void> _showSecuritySettings() async {
    final status = await _lockService.currentStatus();
    final canUseBio = await _bioAdapter.canAuthenticate();

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final pinController = TextEditingController();

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Security & PIN Lock',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AikoColors.primaryBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (status == AppLockStatus.notConfigured) ...[
                    const Text(
                      'Protect your private financial data by configuring a secure 4-digit PIN lock.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pinController,
                      decoration: const InputDecoration(
                        labelText: 'Enter 4-Digit PIN',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () async {
                        final pin = pinController.text.trim();
                        if (pin.length == 4) {
                          await _lockService.configurePin(pin);
                          if (!mounted) return;
                          Navigator.pop(this.context);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN configured successfully!'),
                              backgroundColor: AikoColors.successGreen,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN must be exactly 4 digits.'),
                              backgroundColor: AikoColors.dangerRed,
                            ),
                          );
                        }
                      },
                      child: const Text('Configure PIN'),
                    ),
                  ] else ...[
                    const Text(
                      'PIN lock is currently configured and active.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (canUseBio) ...[
                      ListTile(
                        leading: const Icon(
                          Icons.fingerprint,
                          color: AikoColors.primaryBlue,
                        ),
                        title: const Text('Biometric Authentication'),
                        subtitle: const Text(
                          'Unlock securely using Face ID / Touch ID',
                        ),
                        trailing: Switch(
                          value: true,
                          onChanged: (value) async {
                            final success = await _bioAdapter.authenticate(
                              reason: 'Authenticate with device hardware',
                            );
                            if (!mounted) return;
                            if (success) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Hardware biometrics verified successfully!',
                                  ),
                                  backgroundColor: AikoColors.successGreen,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const Divider(),
                    ],
                    ListTile(
                      leading: const Icon(
                        Icons.lock_reset,
                        color: AikoColors.warningOrange,
                      ),
                      title: const Text('Change PIN Lock'),
                      onTap: () {
                        // Reset PIN
                        setModalState(() {
                          _lockService.disablePin();
                          Navigator.pop(context);
                          _showSecuritySettings();
                        });
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_outline,
                        color: AikoColors.dangerRed,
                      ),
                      title: const Text('Disable PIN Lock'),
                      onTap: () async {
                        await _lockService.disablePin();
                        if (!mounted) return;
                        Navigator.pop(this.context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('PIN lock disabled.'),
                            backgroundColor: AikoColors.warningOrange,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    setState(() => _isSigningOut = true);
    try {
      await _authRepository.signOut();
      if (!mounted) {
        return;
      }
      context.go('/');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out right now.')),
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account and all associated data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AikoColors.dangerRed,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await _authRepository.deleteAccount();
      if (!mounted) return;
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete account right now.')),
      );
    }
  }

  Future<void> _showLanguageSettings(Locale currentLocale) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Language',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                for (final option in _languageOptions)
                  ListTile(
                    key: ValueKey('language-option-${option.languageCode}'),
                    leading: Text(
                      option.languageCode.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AikoColors.primaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    title: Text(option.label),
                    subtitle: Text(option.nativeLabel),
                    trailing: currentLocale.languageCode == option.languageCode
                        ? const Icon(
                            Icons.check_circle,
                            color: AikoColors.successGreen,
                          )
                        : null,
                    onTap: () async {
                      await ref
                          .read(appLocaleControllerProvider.notifier)
                          .setLocale(Locale(option.languageCode));
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAppearanceSettings(Profile profile) async {
    PreferredTheme selectedTheme = profile.preferredTheme;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Appearance',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    RadioGroup<PreferredTheme>(
                      groupValue: selectedTheme,
                      onChanged: (value) async {
                        if (value == null) return;
                        setModalState(() => selectedTheme = value);
                        await ref
                            .read(profileRepositoryProvider)
                            .save(profile.copyWith(preferredTheme: value));
                        ref.invalidate(profileProvider);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                      child: Column(
                        children: [
                          for (final theme in PreferredTheme.values)
                            RadioListTile<PreferredTheme>(
                              key: ValueKey('appearance-option-${theme.name}'),
                              contentPadding: EdgeInsets.zero,
                              value: theme,
                              title: Text(_themeLabel(theme)),
                              secondary: Icon(_themeIcon(theme)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale =
        ref.watch(appLocaleControllerProvider).asData?.value ??
        AppLocaleController.fallbackLocale;
    final currentLanguage = _languageLabelFor(currentLocale);
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          FinanceCard(
            title: 'Profile and privacy',
            icon: Icons.privacy_tip_outlined,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.person_outline,
                  title: 'Profile',
                  onTap: () => context.push('/profile'),
                ),
                const Divider(),
                _SettingsRow(
                  icon: Icons.lock_outline,
                  title: 'Security',
                  onTap: _showSecuritySettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FinanceCard(
            title: 'App preferences',
            icon: Icons.tune_outlined,
            accentColor: AikoColors.premiumPurple,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: profile == null
                      ? 'Loading...'
                      : _themeLabel(profile.preferredTheme),
                  onTap: profile == null
                      ? null
                      : () => _showAppearanceSettings(profile),
                ),
                const Divider(),
                _SettingsRow(
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: currentLanguage,
                  onTap: () => _showLanguageSettings(currentLocale),
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
          const SizedBox(height: 16),
          FinanceCard(
            title: 'Account',
            icon: Icons.account_circle_outlined,
            accentColor: AikoColors.dangerRed,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.logout,
                  title: _isSigningOut ? 'Logging out...' : 'Log out',
                  subtitle: 'End this session on this device',
                  color: AikoColors.dangerRed,
                  trailing: _isSigningOut
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isSigningOut ? null : _handleLogout,
                ),
                const Divider(),
                _SettingsRow(
                  icon: Icons.delete_forever,
                  title: _isDeleting ? 'Deleting...' : 'Delete account',
                  subtitle: 'Permanently delete your account and all data',
                  color: AikoColors.dangerRed,
                  trailing: _isDeleting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isDeleting ? null : _handleDeleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption({
    required this.languageCode,
    required this.label,
    required this.nativeLabel,
  });

  final String languageCode;
  final String label;
  final String nativeLabel;
}

const _languageOptions = [
  _LanguageOption(languageCode: 'th', label: 'Thai', nativeLabel: 'ไทย'),
  _LanguageOption(languageCode: 'en', label: 'English', nativeLabel: 'English'),
];

String _languageLabelFor(Locale locale) {
  for (final option in _languageOptions) {
    if (option.languageCode == locale.languageCode) {
      return '${option.label} (${option.nativeLabel})';
    }
  }
  return 'Thai (ไทย)';
}

String _themeLabel(PreferredTheme theme) {
  switch (theme) {
    case PreferredTheme.system:
      return 'System default';
    case PreferredTheme.light:
      return 'Light';
    case PreferredTheme.dark:
      return 'Dark';
  }
}

IconData _themeIcon(PreferredTheme theme) {
  switch (theme) {
    case PreferredTheme.system:
      return Icons.brightness_auto;
    case PreferredTheme.light:
      return Icons.light_mode;
    case PreferredTheme.dark:
      return Icons.dark_mode;
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = color == null
        ? null
        : Theme.of(context).textTheme.titleSmall?.copyWith(color: color);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: textStyle),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
      onTap: onTap,
    );
  }
}
