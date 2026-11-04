import 'package:aiko/app/app_lock_gate.dart';
import 'package:aiko/core/security/app_lock.dart';
import 'package:aiko/core/security/biometric_unlock.dart';
import 'package:aiko/core/storage/secure_storage_service.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoBiometrics extends BiometricUnlock {
  const _NoBiometrics();

  @override
  Future<bool> get isAvailable async => false;
}

void main() {
  Future<AppLockStore> pumpApp(WidgetTester tester, {String? pin}) async {
    // A phone (the README's 390px check width).
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppLockStore(MemorySecureStorageService());
    if (pin != null) await store.setPin(pin);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockStoreProvider.overrideWithValue(store),
          biometricUnlockProvider.overrideWithValue(const _NoBiometrics()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => AppLockGate(child: child!),
          home: const Scaffold(body: Text('ledger')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> enter(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(find.widgetWithText(TextButton, digit));
    }
    // The unlock key turns on once the digits are drawn.
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
  }

  testWidgets('without a PIN the app shows straight away', (tester) async {
    await pumpApp(tester);
    expect(find.text('ledger'), findsOneWidget);
    expect(find.text('Aiko is locked'), findsNothing);
  });

  testWidgets('with a PIN the app opens only with that PIN', (tester) async {
    await pumpApp(tester, pin: '2580');
    expect(find.text('Aiko is locked'), findsOneWidget);
    // The app is built underneath but covered.
    expect(find.text('ledger').hitTestable(), findsNothing);

    await enter(tester, '1111');
    expect(find.textContaining('Wrong PIN'), findsOneWidget);
    expect(find.text('Aiko is locked'), findsOneWidget);

    await enter(tester, '2580');
    expect(find.text('Aiko is locked'), findsNothing);
    expect(find.text('ledger').hitTestable(), findsOneWidget);
  });

  testWidgets('the unlock key waits for at least 4 digits', (tester) async {
    await pumpApp(tester, pin: '2580');
    await tester.tap(find.widgetWithText(TextButton, '2'));
    await tester.pump();
    final unlock = tester.widget<TextButton>(
      find.ancestor(
        of: find.byIcon(Icons.check),
        matching: find.byType(TextButton),
      ),
    );
    expect(unlock.onPressed, isNull);
  });
}
