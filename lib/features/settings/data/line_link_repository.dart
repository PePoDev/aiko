import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';

/// Redeems a LINE pairing code from inside the app.
///
/// The LINE bot DMs the user a short code (a `line_pairings` row keyed by their
/// LINE user id). Because the user is already signed in here, we can finish the
/// link ourselves. Redemption goes through the `redeem_line_pairing` RPC (a
/// SECURITY DEFINER function) so `line_pairings` is never client-readable — the
/// app only ever hands over a code + its own session refresh token, and the
/// function resolves the code, writes `line_links`, and consumes the pairing
/// server-side under the caller's `auth.uid()`.
class LineLinkRepository {
  const LineLinkRepository();

  /// Throws [LineLinkException] with a user-facing message on any failure.
  Future<void> connectWithCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw const LineLinkException('Enter the code from the LINE bot.');
    }

    final client = AikoSupabase.tryClient();
    final session = client?.auth.currentSession;
    if (client == null || session == null) {
      throw const LineLinkException('Sign in first, then connect LINE.');
    }
    final refreshToken = session.refreshToken;
    if (refreshToken == null) {
      throw const LineLinkException(
        'Your session has no refresh token. Sign out and back in, then retry.',
      );
    }

    final bool redeemed;
    try {
      redeemed =
          await client.rpc(
                'redeem_line_pairing',
                params: {'p_code': code, 'p_refresh_token': refreshToken},
              )
              as bool;
    } on PostgrestException catch (error) {
      throw LineLinkException('Could not save the link: ${error.message}');
    }

    if (!redeemed) {
      throw const LineLinkException(
        'That code is invalid or expired. Message the bot again for a new one.',
      );
    }
  }
}

class LineLinkException implements Exception {
  const LineLinkException(this.message);

  final String message;

  @override
  String toString() => message;
}
