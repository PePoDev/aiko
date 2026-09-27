const String kDefaultBaseCurrency = 'THB';
const String kDefaultCountry = 'TH';

class AppConfig {
  const AppConfig({
    this.firebaseProjectId = '',
    this.firebaseApiKey = '',
    this.firebaseAppId = '',
    this.firebaseMessagingSenderId = '',
    this.firebaseStorageBucket = '',
    this.firebaseAuthDomain = '',
    this.firebaseEmulatorHost = '',
    this.firebaseRegion = 'us-central1',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    firebaseProjectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    firebaseApiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    firebaseAppId: String.fromEnvironment('FIREBASE_APP_ID'),
    firebaseMessagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    firebaseStorageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    firebaseAuthDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    firebaseEmulatorHost: String.fromEnvironment('FIREBASE_EMULATOR_HOST'),
    firebaseRegion: String.fromEnvironment(
      'FIREBASE_REGION',
      defaultValue: 'us-central1',
    ),
  );

  final String firebaseProjectId;
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseMessagingSenderId;
  final String firebaseStorageBucket;
  final String firebaseAuthDomain;
  final String firebaseEmulatorHost;
  final String firebaseRegion;
  bool get usesEmulators => firebaseEmulatorHost.isNotEmpty;
  bool get hasFirebase => usesEmulators || firebaseProjectId.isNotEmpty;
}
