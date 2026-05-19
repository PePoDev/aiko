import '../domain/aiko_character_profile.dart';

class AikoCharacterRepository {
  AikoCharacterRepository({
    AikoCharacterProfile initialProfile = const AikoCharacterProfile(
      visibility: AikoCharacterVisibility.full,
      tone: AikoCharacterTone.supportive,
    ),
  }) : _profile = initialProfile;

  AikoCharacterProfile _profile;

  AikoCharacterProfile load() => _profile;

  void save(AikoCharacterProfile profile) {
    _profile = profile;
  }
}
