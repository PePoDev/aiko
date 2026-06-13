import 'dart:async';

import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/auth/data/auth_repository.dart';
import 'package:aiko/features/auth/presentation/auth_screens.dart';
import 'package:aiko/theme/aiko_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('email field starts empty on login screen', (tester) async {
    final repository = _FakeGoogleAuthRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AikoTheme.light(),
        home: LoginScreen(authRepository: repository),
      ),
    );

    await tester.pumpAndSettle();

    final emailField = tester.widget<TextField>(find.byType(TextField).first);

    expect(emailField.controller?.text, isEmpty);
  });

  testWidgets('google sign in completion routes to home', (tester) async {
    final repository = _FakeGoogleAuthRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AikoTheme.light(),
        routerConfig: GoRouter(
          initialLocation: '/auth',
          routes: [
            GoRoute(
              path: '/auth',
              builder: (context, state) =>
                  LoginScreen(authRepository: repository),
            ),
            GoRoute(
              path: '/home',
              builder: (context, state) => const Scaffold(body: Text('Home')),
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    expect(repository.startedGoogleSignIn, isTrue);

    repository.emitSignedIn();
    await tester.pumpAndSettle();

    expect(repository.restoredSession, isTrue);
    expect(find.text('Home'), findsOneWidget);
  });
}

class _FakeGoogleAuthRepository extends AuthRepository {
  _FakeGoogleAuthRepository() : super(storage: MemorySecureStorageService());

  final _controller = StreamController<AuthState>.broadcast();
  var startedGoogleSignIn = false;
  var restoredSession = false;
  var activeSession = false;

  @override
  Stream<AuthState> authStateChanges() => _controller.stream;

  @override
  Future<bool> signInWithGoogle() async {
    startedGoogleSignIn = true;
    return true;
  }

  @override
  Future<AuthSession?> restoreSession() async {
    restoredSession = true;
    activeSession = true;
    return const AuthSession(userId: 'user-id', email: 'user@example.com');
  }

  @override
  bool hasActiveSession() => activeSession;

  void emitSignedIn() {
    _controller.add(const AuthState(AuthChangeEvent.signedIn, null));
  }

  Future<void> dispose() {
    return _controller.close();
  }
}
