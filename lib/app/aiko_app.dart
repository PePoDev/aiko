import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../features/auth/data/auth_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/aiko_theme.dart';
import 'app_router.dart';

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
      initialLocation: _authRepository.hasActiveSession() ? '/home' : '/',
    );
    _authRepository.restoreSessionInBackground();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'Aiko',
        theme: AikoTheme.light(),
        darkTheme: AikoTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('th'), Locale('en')],
        locale: const Locale('th'),
        routerConfig: _router,
      ),
    );
  }
}
