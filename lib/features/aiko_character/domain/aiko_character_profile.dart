enum AikoCharacterVisibility { full, reduced, hidden }

enum AikoCharacterTone { supportive, professional }

class AikoCharacterProfile {
  const AikoCharacterProfile({
    required this.visibility,
    required this.tone,
    this.reduceMotion = false,
    this.seriousWarningMode = true,
  });

  final AikoCharacterVisibility visibility;
  final AikoCharacterTone tone;
  final bool reduceMotion;
  final bool seriousWarningMode;

  bool get canShowCharacter => visibility != AikoCharacterVisibility.hidden;

  AikoCharacterProfile copyWith({
    AikoCharacterVisibility? visibility,
    AikoCharacterTone? tone,
    bool? reduceMotion,
    bool? seriousWarningMode,
  }) {
    return AikoCharacterProfile(
      visibility: visibility ?? this.visibility,
      tone: tone ?? this.tone,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      seriousWarningMode: seriousWarningMode ?? this.seriousWarningMode,
    );
  }
}
