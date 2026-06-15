import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/accounts/domain/account_details.dart';
import 'package:aiko/features/accounts/presentation/account_form/subforms/credit_card_subform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders initial values', (tester) async {
    final initial = CreditCardDetails(
      creditLimit: Money.parse('5000', 'USD'),
      statementDay: 15,
      dueDay: 5,
    );
    await tester.pumpWidget(
      wrap(
        Consumer(
          builder: (_, ref, _) {
            return CreditCardSubform(
              initial: initial,
              availableCards: const [],
              onChanged: (_) {},
            );
          },
        ),
      ),
    );
    expect(find.text('Statement day (1-31)'), findsOneWidget);
    expect(find.text('Due day (1-31)'), findsOneWidget);
    expect(find.text('Credit limit'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);
  });

  testWidgets('validate fails when limit missing', (tester) async {
    final key = GlobalKey<CreditCardSubformState>();
    await tester.pumpWidget(
      wrap(
        Consumer(
          builder: (_, ref, _) {
            return CreditCardSubform(
              key: key,
              initial: const CreditCardDetails(statementDay: 1, dueDay: 1),
              availableCards: const [],
              onChanged: (_) {},
            );
          },
        ),
      ),
    );
    final state = key.currentState!;
    expect(state.validate(), isNotNull);
  });

  testWidgets('sharesLimit toggle reveals picker and emits null limit', (
    tester,
  ) async {
    final parent = Account(
      id: 'parent',
      userId: 'u',
      name: 'Parent',
      type: AccountType.creditCard,
      currentBalance: Money.zero('USD'),
    );
    CreditCardDetails? captured;
    await tester.pumpWidget(
      wrap(
        Consumer(
          builder: (_, ref, _) {
            return CreditCardSubform(
              initial: const CreditCardDetails(statementDay: 1, dueDay: 1),
              availableCards: [parent],
              onChanged: (d) => captured = d,
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Share limit with another card'));
    await tester.pumpAndSettle();
    expect(captured, isNotNull);
    expect(captured!.sharesLimit, true);
    expect(captured!.creditLimit, isNull);
  });
}
