import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class SupabaseSession {
  const SupabaseSession({required this.client, required this.user});

  final SupabaseClient client;
  final User user;

  String get userId => user.id;
}

class AikoSupabase {
  const AikoSupabase._();

  static bool _initialized = false;

  static Future<void> initialize(AppConfig config) async {
    if (!config.enableSupabase || _initialized) {
      return;
    }
    if (!config.supabaseUrl.startsWith('https://')) {
      throw ArgumentError(
        'SUPABASE_URL must be a Supabase Cloud HTTPS project URL.',
      );
    }
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );
    _initialized = true;
  }

  static SupabaseClient? tryClient() {
    if (!_initialized) {
      return null;
    }
    return Supabase.instance.client;
  }

  static SupabaseClient requireClient() {
    final client = tryClient();
    if (client == null) {
      throw StateError(
        'Supabase is required. Run Aiko with SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
    return client;
  }

  static SupabaseSession requireSession() {
    final client = requireClient();
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before accessing your financial data.');
    }
    return SupabaseSession(client: client, user: user);
  }
}
