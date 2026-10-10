import 'package:firebase_auth/firebase_auth.dart';

import '../../../l10n/app_localizations.dart';

/// A message the user can act on, in their language, for an error thrown by
/// sign-in, sign-up, password reset or account linking. Firebase's own
/// `message` is English-only, so errors are mapped by code; anything
/// unrecognized shows [fallback].
String authErrorMessage(
  Object error,
  AppLocalizations l10n, {
  required String fallback,
}) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => l10n.authErrorInvalidEmail,
      'user-disabled' => l10n.authErrorUserDisabled,
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'INVALID_LOGIN_CREDENTIALS' => l10n.authErrorWrongCredentials,
      'email-already-in-use' ||
      'credential-already-in-use' => l10n.authErrorEmailInUse,
      'weak-password' => l10n.authErrorWeakPassword,
      'too-many-requests' => l10n.authErrorTooManyRequests,
      'network-request-failed' => l10n.authErrorNetwork,
      'operation-not-allowed' => l10n.authErrorMethodDisabled,
      'popup-closed-by-user' ||
      'cancelled-popup-request' ||
      'web-context-canceled' => l10n.authErrorCancelled,
      'account-exists-with-different-credential' => l10n.authErrorOtherProvider,
      'requires-recent-login' => l10n.authErrorRecentLogin,
      _ => fallback,
    };
  }
  if (error is StateError && error.message.contains('not configured')) {
    return l10n.authNotConfigured;
  }
  return fallback;
}
