import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/accounts/domain/account.dart';
import 'package:aiko/features/onboarding/application/onboarding_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding reaches completed after required steps', () {
    final controller = OnboardingController()
      ..chooseFocus('Track spending')
      ..chooseCurrency('USD', 'US')
      ..addFirstAccount(
        Account(
          id: 'cash',
          userId: 'user',
          name: 'Cash',
          type: AccountType.cash,
          openingBalance: Money.zero('USD'),
          currentBalance: Money.zero('USD'),
        ),
      )
      ..setAiConsent(true)
      ..completeSecurity();

    expect(controller.state.canComplete, isTrue);
  });
}
