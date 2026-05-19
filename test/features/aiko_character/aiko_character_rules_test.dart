import 'package:aiko/features/aiko_character/application/aiko_character_policy.dart';
import 'package:aiko/features/aiko_character/domain/aiko_character_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows useful placement and blocks decorative placement', () {
    const policy = AikoCharacterPolicy();
    const profile = AikoCharacterProfile(
      visibility: AikoCharacterVisibility.full,
      tone: AikoCharacterTone.supportive,
    );

    expect(
      policy.allowsPlacement(profile, AikoCharacterPlacement.insightCard),
      isTrue,
    );
    expect(
      policy.allowsPlacement(profile, AikoCharacterPlacement.decorative),
      isFalse,
    );
  });

  test('hidden character preference blocks all placements', () {
    const policy = AikoCharacterPolicy();
    const profile = AikoCharacterProfile(
      visibility: AikoCharacterVisibility.hidden,
      tone: AikoCharacterTone.supportive,
    );

    expect(
      policy.allowsPlacement(profile, AikoCharacterPlacement.onboarding),
      isFalse,
    );
  });

  test('serious warning copy avoids blame language', () {
    const policy = AikoCharacterPolicy();

    expect(policy.warningCopy('your card payment'), isNot(contains('failed')));
    expect(policy.warningCopy('your card payment'), contains('Review'));
  });
}
