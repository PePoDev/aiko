import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/aiko_character_profile.dart';

class AikoCharacterRepository {
  const AikoCharacterRepository();

  Future<AikoCharacterProfile> load() async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return const AikoCharacterProfile(
        visibility: AikoCharacterVisibility.full,
        tone: AikoCharacterTone.supportive,
      );
    }

    final Map<String, dynamic>? row;
    try {
      row = await client
          .from('aiko_character_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
    } catch (_) {
      return const AikoCharacterProfile(
        visibility: AikoCharacterVisibility.full,
        tone: AikoCharacterTone.supportive,
      );
    }

    if (row == null) {
      const profile = AikoCharacterProfile(
        visibility: AikoCharacterVisibility.full,
        tone: AikoCharacterTone.supportive,
      );
      await save(profile);
      return profile;
    }

    return _fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> save(AikoCharacterProfile profile) async {
    final client = AikoSupabase.tryClient();
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return;
    }
    try {
      await client.from('aiko_character_profiles').upsert({
        'user_id': user.id,
        'visibility': profile.visibility.name,
        'tone': profile.tone.name,
        'reduce_motion': profile.reduceMotion,
        'serious_warning_style': profile.seriousWarningMode
            ? 'professional'
            : 'friendly',
      }, onConflict: 'user_id');
    } catch (_) {
      return;
    }
  }

  static AikoCharacterProfile _fromRow(Map<String, dynamic> row) {
    final visibility = AikoCharacterVisibility.values.firstWhere(
      (item) => item.name == (row['visibility'] as String? ?? 'full'),
      orElse: () => AikoCharacterVisibility.full,
    );
    final tone = AikoCharacterTone.values.firstWhere(
      (item) => item.name == (row['tone'] as String? ?? 'supportive'),
      orElse: () => AikoCharacterTone.supportive,
    );

    return AikoCharacterProfile(
      visibility: visibility,
      tone: tone,
      reduceMotion: row['reduce_motion'] as bool? ?? false,
      seriousWarningMode:
          (row['serious_warning_style'] as String? ?? 'professional') ==
          'professional',
    );
  }
}
