import '../domain/aiko_character_profile.dart';

enum AikoCharacterPlacement {
  onboarding,
  dashboardGreeting,
  insightCard,
  seriousWarning,
  decorative,
}

class AikoCharacterPolicy {
  const AikoCharacterPolicy();

  bool allowsPlacement(
    AikoCharacterProfile profile,
    AikoCharacterPlacement placement,
  ) {
    if (!profile.canShowCharacter) {
      return false;
    }

    return placement != AikoCharacterPlacement.decorative;
  }

  String warningCopy(String subject) {
    return 'Aiko notice: $subject needs attention. Review the details before making a decision.';
  }

  String encouragementCopy(String subject) {
    return 'You are making progress with $subject. A small next step can keep things moving.';
  }
}
