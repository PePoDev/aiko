import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/config/app_config.dart';
import '../../../core/offline/firestore_sync_state.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/offline/records/records.dart';
import '../../../core/firebase/firebase_backend.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../l10n/l10n.dart';
import '../domain/profile.dart';

class ProfileRepository {
  /// [store], [userContext], [deviceStorage] and [sync] default to the app's;
  /// tests replace them.
  const ProfileRepository({
    OfflineStore? store,
    OfflineUserContext? userContext,
    SecureStorageService? deviceStorage,
    FirestoreSyncState? sync,
  }) : _store = store,
       _userContext = userContext,
       _deviceStorage = deviceStorage,
       _sync = sync;

  final OfflineStore? _store;
  final OfflineUserContext? _userContext;
  final SecureStorageService? _deviceStorage;
  final FirestoreSyncState? _sync;

  /// Signed-in users whose profile shown is a stand-in: their profile
  /// document isn't on this device yet (offline right after sign-in, or a
  /// reinstall that kept the session), so it may well exist on the server.
  static final _placeholders = <String, Profile>{};

  /// Users known (this run) to have no deferred changes on this device, so
  /// loads skip the device-storage read.
  static final _withoutDeferred = <String>{};

  OfflineStore get _offlineStore => _store ?? OfflineStore();
  SecureStorageService get _device =>
      _deviceStorage ?? FlutterSecureStorageService();
  FirestoreSyncState get _syncState => _sync ?? FirestoreSyncState.instance;

  Future<String> _resolveUserId() =>
      (_userContext ?? OfflineUserContext()).resolveUserId();

  Future<Profile> load() async {
    final userId = await _resolveUserId();
    final store = _offlineStore;
    final stored = await _storedProfile(store, userId);
    if (stored != null) {
      _placeholders.remove(userId);
      if (!store.canSyncRemote) return stored;
      // Changes saved while this profile was a placeholder go on top now.
      return _applyDeferredChanges(store, userId, stored);
    }

    final profile = _defaultProfile(userId);
    // Signed in, the profile document is created once, at sign-in
    // (AuthRepository.ensureProfileAndDefaultsExist). Writing one here
    // would re-create the document of an account that is being deleted;
    // the user's first Save stores it if it's still missing.
    if (!store.canSyncRemote) return save(profile);
    if (_syncState.isServerSynced('profiles')) {
      _placeholders.remove(userId);
    } else {
      _placeholders[userId] = profile;
    }
    final deferred = await _deferredChanges(userId);
    return deferred == null ? profile : _withChanges(profile, deferred);
  }

  Future<Profile> save(Profile profile) async {
    final userId = await _resolveUserId();
    final store = _offlineStore;
    final next = profile.copyWith(id: userId);
    final placeholder = store.canSyncRemote ? _placeholders[userId] : null;
    if (placeholder != null) {
      final changes = profileChanges(placeholder, next);
      final stored = await _storedProfile(store, userId);
      if (stored == null) {
        // Writing the stand-in would replace the real profile document when
        // the device syncs. Keep only what the user changed, on this device,
        // until the real profile arrives (see [load]).
        await _deferChanges(userId, changes);
        return next;
      }
      // The real profile arrived meanwhile: change only those fields.
      _placeholders.remove(userId);
      return _applyDeferredChanges(store, userId, stored, extra: changes);
    }
    final saved = await store.upsert(next.toOffline());
    if (store.canSyncRemote) await _clearDeferredChanges(userId);
    return saved.toDomain();
  }

  Future<Profile?> _storedProfile(OfflineStore store, String userId) async {
    final profiles = await store.get<OfflineProfile>(
      query: RecordQuery(id: userId, limit: 1),
    );
    return profiles.isEmpty ? null : profiles.first.toDomain();
  }

  Profile _defaultProfile(String userId) {
    final email = FirebaseBackend.auth?.currentUser?.email ?? '';
    return Profile(
      id: userId,
      displayName: email.contains('@')
          ? email.split('@').first
          : currentL10n().profileDefaultDisplayName,
      email: email,
      baseCurrency: kDefaultBaseCurrency,
      country: kDefaultCountry,
      securityStatus: SecurityStatus.notConfigured,
      preferredTheme: resolveInitialTheme(),
    );
  }

  Future<Profile> _applyDeferredChanges(
    OfflineStore store,
    String userId,
    Profile stored, {
    Map<String, dynamic> extra = const {},
  }) async {
    final changes = {...?await _deferredChanges(userId), ...extra};
    if (changes.isEmpty) return stored;
    final merged = _withChanges(stored, changes);
    final saved = await store.upsert(merged.toOffline());
    await _clearDeferredChanges(userId);
    return saved.toDomain();
  }

  String _deferredKey(String userId) => '$userId:profile_changes_v1';

  Future<Map<String, dynamic>?> _deferredChanges(String userId) async {
    if (_withoutDeferred.contains(userId)) return null;
    try {
      final raw = await _device.read(_deferredKey(userId));
      if (raw == null) {
        _withoutDeferred.add(userId);
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      // Every stored profile field is a string or empty.
      return {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (key is String && (value is String || value == null)) key: value,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _deferChanges(
    String userId,
    Map<String, dynamic> changes,
  ) async {
    final all = {...?await _deferredChanges(userId), ...changes};
    _withoutDeferred.remove(userId);
    await _device.write(_deferredKey(userId), jsonEncode(all));
  }

  Future<void> _clearDeferredChanges(String userId) async {
    if (_withoutDeferred.contains(userId)) return;
    try {
      await _device.delete(_deferredKey(userId));
      _withoutDeferred.add(userId);
    } catch (_) {
      // Already applied; a leftover copy would only re-apply the same values.
    }
  }

  /// Resolves the device's current platform brightness to an explicit
  /// [PreferredTheme] (light or dark) used to seed a first-launch profile.
  /// `system` is intentionally avoided so the user's first-launch intent is
  /// preserved even if the device theme later changes; they can still switch
  /// back to "System" from the Appearance settings at any time. Reads through
  /// [WidgetsBinding.platformDispatcher] so the test binding's
  /// `platformBrightnessTestValue` is honored in tests.
  static PreferredTheme resolveInitialTheme() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark
        ? PreferredTheme.dark
        : PreferredTheme.light;
  }

  @visibleForTesting
  static void resetPlaceholders() {
    _placeholders.clear();
    _withoutDeferred.clear();
  }
}

/// The stored fields (profile document fields) that differ between [before]
/// and [after], with their new values.
Map<String, dynamic> profileChanges(Profile before, Profile after) {
  final codec = RecordCodecs.profiles;
  final from = codec.toRow(before.toOffline());
  final to = codec.toRow(after.toOffline());
  return {
    for (final MapEntry(:key, :value) in to.entries)
      if (!_bookkeeping.contains(key) && from[key] != value) key: value,
  };
}

const _bookkeeping = {'id', 'updated_at', 'version'};

/// [profile] with the stored fields in [changes] replaced.
Profile _withChanges(Profile profile, Map<String, dynamic> changes) {
  final codec = RecordCodecs.profiles;
  final row = {...codec.toRow(profile.toOffline())};
  for (final MapEntry(:key, :value) in changes.entries) {
    if (!_bookkeeping.contains(key)) row[key] = value;
  }
  return codec.fromRow(row).toDomain();
}
