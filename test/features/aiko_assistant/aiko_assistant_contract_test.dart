import 'package:aiko/core/money/money.dart';
import 'package:aiko/features/aiko_assistant/application/aiko_assistant_service.dart';
import 'package:aiko/features/aiko_assistant/domain/aiko_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assistant returns missing data when consent disabled', () {
    final response = const AikoAssistantService().safeToSpend(
      aiConsentEnabled: false,
      safeToSpendAmount: Money.zero('USD'),
    );

    expect(response.type, AikoResponseType.missingData);
    expect(response.missingData, contains('ai_consent'));
  });

  test('assistant safe-to-spend answer includes disclaimer and sources', () {
    final response = const AikoAssistantService().safeToSpend(
      aiConsentEnabled: true,
      safeToSpendAmount: Money.parse('245', 'USD'),
    );

    expect(response.answer, contains('245'));
    expect(response.hasDisclaimer, isTrue);
    expect(response.sourceSummary, contains('posted_transactions'));
  });
}
