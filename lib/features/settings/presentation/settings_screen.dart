import '../../../core/firebase/firebase_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/aiko_navigation.dart';
import '../../../app/providers.dart';
import '../../../app/locale_controller.dart';
import '../../../l10n/domain_labels.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../shared/widgets/aiko_snack_bar.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../../auth/data/guest_mode.dart';
import '../../auth/presentation/guest_sign_in_tile.dart';
import '../domain/profile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _showLanguageSettings(AppLocaleState localeState) async {
    await showAikoSheet<void>(
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
                  context.l10n.languageTitle,
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
                  title: Text(context.l10n.languageSystemDefault),
                  subtitle: Text(
                    context.l10n.languageFollowDevice(
                      _languageLabelFor(localeState.locale, context.l10n),
                    ),
                  ),
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
                    title: Text(option.label(context.l10n)),
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
    final messenger = ScaffoldMessenger.of(context);

    await showAikoSheet<void>(
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
                      context.l10n.appearanceTitle,
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
                        final l10n = context.l10n;
                        final navigator = Navigator.of(context);
                        setModalState(() => selectedTheme = value);
                        try {
                          await ref
                              .read(profileRepositoryProvider)
                              .save(profile.copyWith(preferredTheme: value));
                          ref.invalidate(profileProvider);
                        } catch (error) {
                          debugPrint('[settings] theme save failed: $error');
                          if (context.mounted) navigator.pop();
                          messenger.showSnackBar(
                            aikoSnackBar(
                              l10n.settingsAppearanceSaveFailed,
                              tone: AikoSnackTone.error,
                            ),
                          );
                          return;
                        }
                        if (!context.mounted) return;
                        navigator.pop();
                      },
                      child: Column(
                        children: [
                          for (final theme in PreferredTheme.values)
                            RadioListTile<PreferredTheme>(
                              key: ValueKey('appearance-option-${theme.name}'),
                              contentPadding: EdgeInsets.zero,
                              value: theme,
                              title: Text(_themeLabel(theme, context.l10n)),
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
    final l10n = context.l10n;
    final currentLanguage = localeState == null
        ? _languageLabelFor(locale, l10n)
        : localeState.followsSystem
        ? l10n.languageSystemDefaultWith(_languageLabelFor(locale, l10n))
        : _languageLabelFor(locale, l10n);
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.value;
    final profileFailed = profile == null && profileAsync.hasError;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          if (!FirebaseBackend.isConfigured)
            ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: Text(l10n.settingsLocalOnlyTitle),
              subtitle: Text(l10n.settingsLocalOnlyMessage),
            ),
          // Guests: a cloud build used without an account.
          if (GuestMode.isCurrent) const GuestSignInTile(),
          FinanceCard(
            title: l10n.settingsAppPreferences,
            icon: Icons.tune_outlined,
            accentColor: AikoColors.premiumPurple,
            child: Column(
              children: [
                // Phones reach Profile from here (wide screens also have it
                // in the sidebar).
                _SettingsRow(
                  icon: Icons.person_outline,
                  title: l10n.profileTitle,
                  subtitle: l10n.settingsProfileSubtitle,
                  onTap: () => context.push('/profile'),
                ),
                const Divider(),
                _SettingsRow(
                  icon: Icons.palette_outlined,
                  title: l10n.appearanceTitle,
                  subtitle: profile != null
                      ? _themeLabel(profile.preferredTheme, l10n)
                      : profileFailed
                      ? l10n.settingsAppearanceLoadFailed
                      : l10n.loadingEllipsis,
                  onTap: profile != null
                      ? () => _showAppearanceSettings(profile)
                      : profileFailed
                      ? () => ref.invalidate(profileProvider)
                      : null,
                ),
                const Divider(),
                _SettingsRow(
                  icon: Icons.language,
                  title: l10n.languageTitle,
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
            title: l10n.settingsToolsAndSettings,
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

  /// The language's name in the current UI language.
  final String Function(AppLocalizations l10n) label;

  /// The language's name in itself; not translated.
  final String nativeLabel;
}

String _thaiLabel(AppLocalizations l10n) => l10n.languageThai;
String _englishLabel(AppLocalizations l10n) => l10n.languageEnglish;

const _languageOptions = [
  _LanguageOption(languageCode: 'th', label: _thaiLabel, nativeLabel: 'ไทย'),
  _LanguageOption(
    languageCode: 'en',
    label: _englishLabel,
    nativeLabel: 'English',
  ),
];

String _languageLabelFor(Locale locale, AppLocalizations l10n) {
  final option = _languageOptions.firstWhere(
    (option) => option.languageCode == locale.languageCode,
    orElse: () => _languageOptions.first,
  );
  final label = option.label(l10n);
  return label == option.nativeLabel ? label : '$label (${option.nativeLabel})';
}

String _themeLabel(PreferredTheme theme, AppLocalizations l10n) =>
    theme.label(l10n);

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
      title: Text(item.label(context.l10n)),
      subtitle: Text(item.description(context.l10n)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(item.path),
    );
  }
}
