import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_bootstrap.dart';

void main() {
  testWidgets(
    'app login flow creates and cleans up account',
    (tester) async {
      IntegrationTestAccount? account;
      await bootstrapIntegrationTest(tester);
      try {
        account = await createIntegrationTestAccount();

        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();

        for (var index = 0; index < 4; index++) {
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
        }

        final finishAndSignIn = find.text('Finish & Sign In');
        if (finishAndSignIn.evaluate().isNotEmpty) {
          await tester.tap(finishAndSignIn);
        } else {
          await tester.tap(find.text('Continue to sign in'));
        }
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(0), account.email);
        await tester.enterText(find.byType(TextField).at(1), account.password);
        await tester.tap(find.text('Continue securely'));
        await tester.pumpAndSettle();

        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Aiko Hub'), findsOneWidget);
      } finally {
        if (account != null) {
          await cleanupIntegrationTestAccount(account);
        }
      }
    },
    skip: !hasSupabaseProjectConfig,
  );
}
