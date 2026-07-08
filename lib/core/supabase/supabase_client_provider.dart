import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AikoSupabase {
  const AikoSupabase._();

  static bool _initialized = false;

  static bool isSupportedProjectUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }

    if (uri.scheme == 'https') {
      return true;
    }

    if (uri.scheme != 'http') {
      return false;
    }

    final host = uri.host.toLowerCase();
    return host == 'localhost' ||
        host == '10.0.2.2' ||
        host == '::1' ||
        host == '127.0.0.1' ||
        host.startsWith('127.');
  }

  static Future<void> initialize(
    AppConfig config, {
    http.Client? httpClient,
  }) async {
    if (_initialized ||
        config.supabaseUrl.isEmpty ||
        config.supabaseAnonKey.isEmpty) {
      return;
    }
    if (!isSupportedProjectUrl(config.supabaseUrl)) {
      throw ArgumentError(
        'SUPABASE_URL must be an HTTPS URL or a local self-hosted HTTP URL.',
      );
    }
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      httpClient: httpClient,
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
}
