import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/aiko_navigation.dart';
import '../../../app/providers.dart';
import '../../../app/locale_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/profile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _showLanguageSettings(AppLocaleState localeState) async {
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
                ListTile(
                  key: const ValueKey('language-option-system'),
                  leading: const Icon(
                    Icons.smartphone,
                    color: AikoColors.primaryBlue,
                  ),
                  title: const Text('System default'),
                  subtitle: Text(_deviceLanguageSubtitle(localeState.locale)),
                  trailing: localeState.followsSystem
                      ? const Icon(
                          Icons.check_circle,
                          color: AikoColors.successGreen,
                        )
                      : null,
                  onTap: () async {
                    await ref
                        .read(appLocaleControllerProvider.notifier)
                        .followSystemLocale();
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
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
                    trailing:
                        !localeState.followsSystem &&
                            localeState.locale.languageCode ==
                                option.languageCode
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
    final localeState = ref.watch(appLocaleControllerProvider).asData?.value;
    final locale = localeState?.locale ?? AppLocaleController.fallbackLocale;
    final currentLanguage = localeState == null
        ? _languageLabelFor(locale)
        : localeState.followsSystem
        ? 'System default (${_languageLabelFor(locale)})'
        : _languageLabelFor(locale);
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
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
                  onTap: () => _showLanguageSettings(
                    localeState ??
                        AppLocaleState(
                          locale: AppLocaleController.fallbackLocale,
                          followsSystem: true,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FinanceCard(
            title: 'Tools and settings',
            icon: Icons.apps_outlined,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < aikoNavigationItems.length;
                  index++
                ) ...[
                  if (index > 0) const Divider(),
                  _SettingsNavigationTile(item: aikoNavigationItems[index]),
                ],
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
      return option.label == option.nativeLabel
          ? option.label
          : '${option.label} (${option.nativeLabel})';
    }
  }
  return 'Thai (ไทย)';
}

String _deviceLanguageSubtitle(Locale deviceLocale) {
  return 'Follow device language (${_languageLabelFor(deviceLocale)})';
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
