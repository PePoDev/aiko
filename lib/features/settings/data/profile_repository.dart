import '../domain/profile.dart';

class ProfileRepository {
  ProfileRepository({Profile? initial})
    : _profile =
          initial ??
          const Profile(
            id: 'demo-user',
            displayName: 'Aiko User',
            email: 'demo@example.com',
            baseCurrency: 'USD',
            country: 'US',
            aiConsentEnabled: true,
            onboardingStatus: OnboardingStatus.completed,
            securityStatus: SecurityStatus.pinEnabled,
          );

  Profile _profile;

  Future<Profile> load() async => _profile;

  Future<Profile> save(Profile profile) async {
    _profile = profile;
    return _profile;
  }
}
