import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'emulator_defaults.dart';

class FirebaseBackend {
  FirebaseBackend._();
  static bool _ready = false;
  static AppConfig _config = const AppConfig();
  static bool get isConfigured => _ready;
  static FirebaseAuth? get auth => _ready ? FirebaseAuth.instance : null;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;
  static FirebaseFunctions get functions =>
      FirebaseFunctions.instanceFor(region: _config.firebaseRegion);
  static String? get userId => auth?.currentUser?.uid;

  static String get chatUrl => !_ready
      ? ''
      : _config.usesEmulators
      ? 'http://${_config.firebaseEmulatorHost}:5001/${firestore.app.options.projectId}/${_config.firebaseRegion}/aikoChat'
      : 'https://${_config.firebaseRegion}-${_config.firebaseProjectId}.cloudfunctions.net/aikoChat';

  static Future<void> initialize(AppConfig config) async {
    if (_ready || !config.hasFirebase) return;
    _config = config;
    final project = config.firebaseProjectId.isEmpty
        ? 'demo-aiko'
        : config.firebaseProjectId;
    if (config.usesEmulators && !project.startsWith('demo-')) {
      throw ArgumentError(
        'Local emulators must use a demo- Firebase project ID.',
      );
    }
    final options = FirebaseOptions(
      apiKey: config.firebaseApiKey.isEmpty
          ? 'demo-api-key'
          : config.firebaseApiKey,
      appId: config.firebaseAppId.isEmpty
          ? '1:1234567890:web:aiko'
          : config.firebaseAppId,
      messagingSenderId: config.firebaseMessagingSenderId.isEmpty
          ? '1234567890'
          : config.firebaseMessagingSenderId,
      projectId: project,
      authDomain: config.firebaseAuthDomain.isEmpty
          ? '$project.firebaseapp.com'
          : config.firebaseAuthDomain,
      storageBucket: config.firebaseStorageBucket.isEmpty
          ? '$project.appspot.com'
          : config.firebaseStorageBucket,
    );
    if (config.usesEmulators) {
      await configureAuthEmulatorBeforeInitialization(
        options,
        config.firebaseEmulatorHost,
      );
    }
    await Firebase.initializeApp(options: options);
    _ready = true;
    if (config.usesEmulators) {
      if (!kIsWeb) {
        await auth!.useAuthEmulator(config.firebaseEmulatorHost, 9099);
      }
      firestore.useFirestoreEmulator(config.firebaseEmulatorHost, 8081);
      await storage.useStorageEmulator(config.firebaseEmulatorHost, 9199);
      functions.useFunctionsEmulator(config.firebaseEmulatorHost, 5001);
    }
    await auth!.authStateChanges().first;
    if (kIsWeb) {
      await auth!.setPersistence(Persistence.LOCAL);
      firestore.settings = const Settings(
        persistenceEnabled: true,
        webPersistentTabManager: WebPersistentMultipleTabManager(),
      );
    } else {
      firestore.settings = const Settings(persistenceEnabled: true);
    }
  }

  static CollectionReference<Map<String, dynamic>> collection(String name) {
    final uid = userId;
    if (uid == null) throw StateError('Sign in to synchronize your data.');
    return firestore.collection('users').doc(uid).collection(name);
  }
}
