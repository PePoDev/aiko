import 'package:http/http.dart' as http;

/// The browser has no separate connect timeout; the engine's response
/// timeout covers connecting.
http.Client createChatHttpClient(Duration connectTimeout) => http.Client();
