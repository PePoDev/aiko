import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// A client whose TCP connect gives up after [connectTimeout], so a dead or
/// captive network fails fast instead of waiting for the OS.
http.Client createChatHttpClient(Duration connectTimeout) =>
    IOClient(HttpClient()..connectionTimeout = connectTimeout);
