import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../theme/aiko_theme.dart';
import 'app_router.dart';

class AikoApp extends StatelessWidget {
  const AikoApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final router = createAikoRouter();
    return ProviderScope(
      child: MaterialApp.router(
        title: 'Aiko',
        theme: AikoTheme.light(),
        darkTheme: AikoTheme.dark(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        routerConfig: router,
      ),
    );
  }
}
