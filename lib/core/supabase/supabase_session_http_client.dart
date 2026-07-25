import 'package:http/http.dart' as http;

import 'supabase_client_provider.dart';

/// Replaces cached PostgREST bearer headers with the current Supabase session
/// token immediately before transmission.
///
/// Brick persists complete HTTP requests for offline retry, including their
/// authorization header. Supabase rotates and revokes access tokens, so a
/// queued request can otherwise retry an expired token forever.
class SupabaseSessionHttpClient extends http.BaseClient {
  SupabaseSessionHttpClient({
    http.Client? inner,
    String? Function()? accessTokenProvider,
  }) : _inner = inner ?? http.Client(),
       _accessTokenProvider =
           accessTokenProvider ??
           (() => AikoSupabase.tryClient()?.auth.currentSession?.accessToken);

  final http.Client _inner;
  final String? Function() _accessTokenProvider;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final token = _accessTokenProvider();
    if (token != null && request.url.path.startsWith('/rest/v1/')) {
      request.headers['authorization'] = 'Bearer $token';
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
