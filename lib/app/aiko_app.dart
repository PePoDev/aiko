import 'dart:async';

import '../core/firebase/firebase_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/config/app_config.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/guest_mode.dart';
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
  StreamSubscription<Object?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository();
    _router = createAikoRouter(
      initialLocation: initialAppLocation(
        cloud: FirebaseBackend.isConfigured,
        isGuest: GuestMode.isCurrent,
      ),
    );
    _authRepository.restoreSessionInBackground();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeReturningUser();
    });
    // The session can end while the app is open (token revoked, password
    // changed or account deleted elsewhere); leave the signed-in screens then.
    // Guests have no session: Firebase reports "no user" for them at every
    // launch, which must neither clean up nor move them.
    _authSubscription = FirebaseBackend.auth?.authStateChanges().listen((user) {
      if (user == null && !GuestMode.isActive) _leaveShellAfterSignOut();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  String get _location => _router.routeInformationProvider.value.uri.path;

  Future<void> _leaveShellAfterSignOut() async {
    await _authRepository.handleSessionEnded();
    final hasKnownAccount = await _authRepository.hasKnownAccount();
    if (!mounted) return;
    final target = signedOutRedirect(
      _location,
      hasKnownAccount: hasKnownAccount,
      // They may have chosen to continue without an account meanwhile.
      isGuest: GuestMode.isActive,
    );
    if (target != null) _router.go(target);
  }

  Future<void> _routeReturningUser() async {
    if (!FirebaseBackend.isConfigured) return;
    if (!_authRepository.hasActiveSession()) {
      await _authRepository.restoreSession();
      if (!mounted) return;
    }
    final signedIn = _authRepository.hasActiveSession();
    final hasKnownAccount =
        !signedIn &&
        !GuestMode.isActive &&
        await _authRepository.hasKnownAccount();
    if (!mounted) return;
    final target = returningUserRedirect(
      _location,
      signedIn: signedIn,
      isGuest: GuestMode.isActive,
      hasKnownAccount: hasKnownAccount,
    );
    if (target != null) _router.go(target);
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

/// Where the app opens: Welcome for cloud builds, unless the device is used
/// without an account (local-only builds, and guests of cloud builds), which
/// goes straight to Home.
String initialAppLocation({required bool cloud, required bool isGuest}) =>
    !cloud || isGuest ? '/home' : '/';

/// Where to send someone whose session ended while a signed-in screen was
/// open: the login screen when this device knows their account, otherwise
/// Welcome. Null when they are already on Welcome or the login screen, and
/// for guests, who use the app signed out.
String? signedOutRedirect(
  String location, {
  required bool hasKnownAccount,
  bool isGuest = false,
}) {
  if (isGuest || location == '/' || location == '/auth') return null;
  return hasKnownAccount ? '/auth' : '/';
}

/// Where a cloud build moves someone on Welcome or the login screen once it
/// knows who they are at launch: Home when signed in, Home for a guest still
/// on Welcome (a guest on the login screen came to sign in), the login screen
/// for a known account, otherwise nowhere. Other screens are left alone.
String? returningUserRedirect(
  String location, {
  required bool signedIn,
  required bool isGuest,
  required bool hasKnownAccount,
}) {
  if (location != '/' && location != '/auth') return null;
  if (signedIn) return '/home';
  if (location == '/auth') return null;
  if (isGuest) return '/home';
  return hasKnownAccount ? '/auth' : null;
}

ThemeMode themeModeForPreferredTheme(PreferredTheme preferredTheme) {
  return switch (preferredTheme) {
    PreferredTheme.system => ThemeMode.system,
    PreferredTheme.light => ThemeMode.light,
    PreferredTheme.dark => ThemeMode.dark,
  };
}
