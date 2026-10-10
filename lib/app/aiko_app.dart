import '../core/firebase/firebase_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/config/app_config.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/settings/domain/profile.dart';
import '../l10n/app_localizations.dart';
import '../theme/aiko_theme.dart';
import 'app_router.dart';
import 'locale_controller.dart';
import 'providers.dart';

class AikoApp extends StatefulWidget {
  const AikoApp({required this.config, super.key});

  final AppConfig config;

  @override
  State<AikoApp> createState() => _AikoAppState();
}

class _AikoAppState extends State<AikoApp> {
  late final GoRouter _router;
  late final AuthRepository _authRepository;

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository();
    _router = createAikoRouter(
      initialLocation: !FirebaseBackend.isConfigured ? '/home' : '/',
    );
    _authRepository.restoreSessionInBackground();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeReturningUser();
    });
  }

  Future<void> _routeReturningUser() async {
    if (!FirebaseBackend.isConfigured) return;
    if (_authRepository.hasActiveSession()) {
      if ([
        '/',
        '/auth',
      ].contains(_router.routeInformationProvider.value.uri.path)) {
        _router.go('/home');
      }
      return;
    }
    await _authRepository.restoreSession();
    if (!mounted) return;
    if (_authRepository.hasActiveSession()) {
      if ([
        '/',
        '/auth',
      ].contains(_router.routeInformationProvider.value.uri.path)) {
        _router.go('/home');
      }
      return;
    }
    if (await _authRepository.hasKnownAccount()) {
      if (!mounted) return;
      _router.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, child) {
          final localeState = ref
              .watch(appLocaleControllerProvider)
              .asData
              ?.value;
          final locale =
              localeState?.locale ?? AppLocaleController.fallbackLocale;
          // Dates, numbers and money formatted without an explicit locale
          // (DateFormat, NumberFormat) follow the selected language.
          Intl.defaultLocale = locale.languageCode;
          final preferredTheme = ref
              .watch(profileProvider)
              .maybeWhen(
                data: (profile) => profile.preferredTheme,
                orElse: () => PreferredTheme.system,
              );

          return MaterialApp.router(
            title: 'Aiko', // l10n-ignore
            theme: AikoTheme.light(),
            darkTheme: AikoTheme.dark(),
            themeMode: themeModeForPreferredTheme(preferredTheme),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: locale,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

ThemeMode themeModeForPreferredTheme(PreferredTheme preferredTheme) {
  return switch (preferredTheme) {
    PreferredTheme.system => ThemeMode.system,
    PreferredTheme.light => ThemeMode.light,
    PreferredTheme.dark => ThemeMode.dark,
  };
}
