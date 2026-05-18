class AuthSession {
  const AuthSession({required this.userId, required this.email});

  final String userId;
  final String email;
}

class AuthRepository {
  AuthSession? _session;

  Future<AuthSession> signUp({
    required String email,
    required String password,
  }) async {
    _session = AuthSession(userId: 'demo-user', email: email);
    return _session!;
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    _session = AuthSession(userId: 'demo-user', email: email);
    return _session!;
  }

  Future<void> signOut() async {
    _session = null;
  }

  Future<void> resetPassword(String email) async {}

  Future<AuthSession?> restoreSession() async => _session;
}
