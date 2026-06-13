import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/aiko_navigation.dart';
import '../../../app/providers.dart';
import '../../../app/locale_controller.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/profile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
          for (final group in aikoNavigationGroups) ...[
            const SizedBox(height: 16),
            _SettingsNavigationGroupCard(group: group),
          ],
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

class _SettingsNavigationGroupCard extends StatelessWidget {
  const _SettingsNavigationGroupCard({required this.group});

  final AikoNavigationGroup group;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      title: group.title,
      icon: _iconForGroup(group.title),
      accentColor: _colorForGroup(group.title),
      child: Column(
        children: [
          for (var index = 0; index < group.items.length; index++) ...[
            if (index > 0) const Divider(),
            _SettingsNavigationTile(item: group.items[index]),
          ],
        ],
      ),
    );
  }

  IconData _iconForGroup(String title) {
    return switch (title) {
      'Insights and AI' => Icons.auto_awesome_outlined,
      'Tools and Data' => Icons.widgets_outlined,
      'Settings and Security' => Icons.admin_panel_settings_outlined,
      _ => Icons.apps_outlined,
    };
  }

  Color _colorForGroup(String title) {
    return switch (title) {
      'Insights and AI' => AikoColors.premiumPurple,
      'Tools and Data' => AikoColors.analyticsTeal,
      'Settings and Security' => AikoColors.primaryBlue,
      _ => AikoColors.primaryBlue,
    };
  }
}

class _SettingsNavigationTile extends StatelessWidget {
  const _SettingsNavigationTile({required this.item});

  final AikoNavigationItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(item.icon, color: item.accentColor),
      title: Text(item.label),
      subtitle: item.description.isEmpty ? null : Text(item.description),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(item.path),
    );
  }
}
