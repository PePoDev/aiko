import 'package:aiko/core/supabase/supabase_session_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('queued REST request uses the current session token', () async {
    final inner = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer current-token');
      return http.Response('{}', 200);
    });
    final client = SupabaseSessionHttpClient(
      inner: inner,
      accessTokenProvider: () => 'current-token',
    );
    final request = http.Request(
      'POST',
      Uri.parse('http://localhost:8000/rest/v1/transactions'),
    )..headers['authorization'] = 'Bearer expired-token';

    final response = await client.send(request);

    expect(response.statusCode, 200);
  });
}
