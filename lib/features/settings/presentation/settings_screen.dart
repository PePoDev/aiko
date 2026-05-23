import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/security/persistent_secure_app_lock_service.dart';
import '../../../core/security/biometric_auth_adapter.dart';
import '../../../core/security/app_lock_service.dart';
import '../../../core/storage/secure_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authRepository = AuthRepository();
  var _isSigningOut = false;
  var _aiAnalysisEnabled = true;
  var _localOnlyMode = false;

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
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN configured successfully!'),
                              backgroundColor: AikoColors.successGreen,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
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
                        leading: const Icon(Icons.fingerprint, color: AikoColors.primaryBlue),
                        title: const Text('Biometric Authentication'),
                        subtitle: const Text('Unlock securely using Face ID / Touch ID'),
                        trailing: Switch(
                          value: true,
                          onChanged: (value) async {
                            final success = await _bioAdapter.authenticate(
                              reason: 'Authenticate with device hardware',
                            );
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Hardware biometrics verified successfully!'),
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
                      leading: const Icon(Icons.lock_reset, color: AikoColors.warningOrange),
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
                      leading: const Icon(Icons.delete_outline, color: AikoColors.dangerRed),
                      title: const Text('Disable PIN Lock'),
                      onTap: () async {
                        await _lockService.disablePin();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
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
      context.go('/auth');
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

  @override
  Widget build(BuildContext context) {
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
                const Divider(),
                _SettingsRow(
                  icon: Icons.psychology_alt_outlined,
                  title: 'AI consent',
                  subtitle: 'Allow Aiko to analyze financial data',
                  trailing: Switch(
                    value: _aiAnalysisEnabled && !_localOnlyMode,
                    onChanged: _localOnlyMode
                        ? null
                        : (value) => setState(() => _aiAnalysisEnabled = value),
                  ),
                ),
                const Divider(),
                _SettingsRow(
                  icon: Icons.cloud_off_outlined,
                  title: 'Local-only mode',
                  subtitle: 'Disable cloud sync and AI analysis on this device',
                  trailing: Switch(
                    value: _localOnlyMode,
                    onChanged: (value) => setState(() {
                      _localOnlyMode = value;
                      if (value) {
                        _aiAnalysisEnabled = false;
                      }
                    }),
                  ),
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
            child: _SettingsRow(
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
