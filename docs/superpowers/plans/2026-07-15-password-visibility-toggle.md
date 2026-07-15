# Password Visibility Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an accessible show/hide button to the shared login and signup password field while keeping the password hidden by default.

**Architecture:** Keep password visibility as local UI state in `_LoginScreenState`. Drive the existing `TextField.obscureText`, trailing icon, tooltip, and enabled state from that boolean and the existing submission state; authentication logic remains unchanged.

**Tech Stack:** Flutter Material widgets, Dart, `flutter_test`, Riverpod test wrapper

## Global Constraints

- The password starts hidden whenever `LoginScreen` is created.
- The same visibility behavior applies to both Log In and Sign up because they share one password field.
- The trailing action uses the exact tooltips `Show password` and `Hide password`.
- Toggling visibility must not change the password text, focus, or form action.
- The visibility action is disabled while an authentication request is submitting.
- Do not add dependencies, validation rules, authentication changes, or a reusable password-field abstraction.

## Approved Execution Exception

The repository's `README.md` prohibits UI/widget tests. After that rule was
discovered, the user approved implementing this UI-only toggle without the
planned widget test. Verification therefore uses targeted formatting,
`flutter analyze`, and the full existing `flutter test` suite; no test file is
created.

## File Structure

- Create `test/features/auth/login_screen_test.dart` for focused widget behavior tests.
- Modify `lib/features/auth/presentation/auth_screens.dart` only within `_LoginScreenState` and its password `TextField`.

---

### Task 1: Add and verify the password visibility toggle

**Files:**
- Create: `test/features/auth/login_screen_test.dart`
- Modify: `lib/features/auth/presentation/auth_screens.dart:277-286,480-486`

**Interfaces:**
- Consumes: `LoginScreen({AuthRepository? authRepository, Key? key})`, `AuthRepository.signIn({required String email, required String password})`
- Produces: private `_obscurePassword: bool` state and an `IconButton` suffix action; no public API changes

- [ ] **Step 1: Write the failing widget tests**

Create `test/features/auth/login_screen_test.dart`:

```dart
import 'dart:async';

import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/features/auth/data/auth_repository.dart';
import 'package:aiko/features/auth/presentation/auth_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingAuthRepository extends AuthRepository {
  _PendingAuthRepository() : super(storage: MemorySecureStorageService());

  final signInCompleter = Completer<AuthSession>();

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) {
    return signInCompleter.future;
  }
}

Future<void> _pumpLoginScreen(
  WidgetTester tester, {
  AuthRepository? authRepository,
}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: LoginScreen(authRepository: authRepository),
      ),
    ),
  );
}

void main() {
  testWidgets('password can be shown and hidden without clearing it', (
    tester,
  ) async {
    await _pumpLoginScreen(tester);
    final passwordField = find.byType(TextField).at(1);

    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.enterText(passwordField, 'Secret123!');
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
    expect(tester.widget<TextField>(passwordField).controller!.text, 'Secret123!');
    expect(find.byTooltip('Hide password'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();

    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
    expect(tester.widget<TextField>(passwordField).controller!.text, 'Secret123!');
    expect(find.byTooltip('Show password'), findsOneWidget);
  });

  testWidgets('password visibility action is disabled while signing in', (
    tester,
  ) async {
    final repository = _PendingAuthRepository();
    await _pumpLoginScreen(tester, authRepository: repository);

    await tester.enterText(find.byType(TextField).first, 'person@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'Secret123!');
    await tester.tap(find.text('Log In'));
    await tester.pump();

    final toggle = find.widgetWithIcon(
      IconButton,
      Icons.visibility_outlined,
    );
    expect(tester.widget<IconButton>(toggle).onPressed, isNull);

    repository.signInCompleter.completeError(StateError('stop test request'));
    await tester.pumpAndSettle();
  });
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
flutter test test/features/auth/login_screen_test.dart
```

Expected: FAIL because `Show password` and the visibility `IconButton` do not exist while the current password field is permanently obscured.

- [ ] **Step 3: Implement the minimal visibility state and suffix action**

In `_LoginScreenState`, add the visibility state beside `_isSubmitting`:

```dart
  var _isSubmitting = false;
  var _obscurePassword = true;
```

Replace the existing password `TextField` with:

```dart
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  enabled: !_isSubmitting,
                  onSubmitted: (_) => _handleSignIn(),
                ),
```

- [ ] **Step 4: Format and run the focused test to verify GREEN**

Run:

```bash
dart format lib/features/auth/presentation/auth_screens.dart test/features/auth/login_screen_test.dart
flutter test test/features/auth/login_screen_test.dart
```

Expected: both widget tests PASS.

- [ ] **Step 5: Run the full verification suite**

Run:

```bash
flutter test
flutter analyze
```

Expected: all tests PASS and analysis reports `No issues found!`.

- [ ] **Step 6: Commit the implementation**

```bash
git add lib/features/auth/presentation/auth_screens.dart test/features/auth/login_screen_test.dart
git commit -m "feat: add password visibility toggle"
```
