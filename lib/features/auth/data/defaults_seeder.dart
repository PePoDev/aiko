import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, immutable;

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_backend.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/records/records.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category.dart';
import '../../categories/domain/category_defaults.dart';

/// One document an account starts with, at `users/{uid}/{collection}/{id}`.
@immutable
class DefaultSeedDoc {
  const DefaultSeedDoc(this.collection, this.id, this.row);

  final String collection;
  final String id;
  final Map<String, dynamic> row;
}

/// The documents every account starts with: its profile and a clone of each
/// default category group and category. Clone ids are derived from the user
/// and template ids (the ids older versions seeded too), so seeding again, or
/// on another device, never duplicates a default.
///
/// [guestProfile] (set up before signing up, without an account) becomes the
/// new account's profile, under its id and [email]. [guestDefaults] are the
/// defaults a guest gave a budget (stored under their template ids): their
/// clones start with it, so claiming the guest's records right after seeding
/// has nothing to change, whichever write lands first.
List<DefaultSeedDoc> defaultSeedDocs(
  String uid,
  String email, {
  OfflineProfile? guestProfile,
  GuestDefaults guestDefaults = const GuestDefaults(),
}) {
  final emailName = email.contains('@') ? email.split('@').first : email;
  final Map<String, dynamic> profile;
  if (guestProfile == null) {
    profile = {
      'id': uid,
      'email': email,
      'display_name': emailName,
      'base_currency': kDefaultBaseCurrency,
      'country': kDefaultCountry,
      'timezone': defaultProfileTimezone(),
      'preferred_theme': 'system',
      'aiko_character_visibility': 'full',
      'aiko_personality_setting': 'supportive',
      'security_status': 'notConfigured',
      'gender': 'preferNotToSay',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'version': 1,
    };
  } else {
    final placeholderNames = {
      for (final locale in AppLocalizations.supportedLocales)
        lookupAppLocalizations(locale).profileDefaultDisplayName,
    };
    final guestName = guestProfile.displayName.trim();
    profile = {
      ...RecordCodecs.profiles.toRow(guestProfile),
      'id': uid,
      'email': email,
      // A guest who never named themselves gets the email name, as usual.
      'display_name': guestName.isEmpty || placeholderNames.contains(guestName)
          ? emailName
          : guestName,
      // Guests never choose one; an account made directly gets the same.
      'timezone': defaultProfileTimezone(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'version': 1,
    };
  }
  final guestGroups = {
    for (final group in guestDefaults.groups)
      if (group.effectiveTemplateId case final String templateId)
        templateId: group,
  };
  final guestCategories = {
    for (final category in guestDefaults.categories)
      if (category.effectiveTemplateId case final String templateId)
        templateId: category,
  };
  return [
    DefaultSeedDoc(RecordCodecs.profiles.collection, uid, profile),
    for (final template in CategoryGroupDefaults.all)
      _clone(
        RecordCodecs.categoryGroups,
        switch (guestGroups[template.id]) {
          final CategoryGroup group => CategoryGroupDefaults.normalizeForUser(
            group,
            userId: uid,
          ),
          null => CategoryGroupDefaults.cloneForUser(
            userId: uid,
            template: template,
          ),
        }.toOffline(userId: uid),
      ),
    for (final template in CategoryDefaults.all)
      _clone(
        RecordCodecs.categories,
        switch (guestCategories[template.id]) {
          final Category category => CategoryDefaults.normalizeForUser(
            category,
            userId: uid,
          ),
          null => CategoryDefaults.cloneForUser(
            userId: uid,
            template: template,
          ),
        }.toOffline(userId: uid),
      ),
  ];
}

/// The default categories and groups a guest gave a budget, as stored on the
/// device (under their template ids).
@immutable
class GuestDefaults {
  const GuestDefaults({this.categories = const [], this.groups = const []});

  final List<Category> categories;
  final List<CategoryGroup> groups;
}

DefaultSeedDoc _clone<T extends OfflineRecord>(
  RecordCodec<T> codec,
  T record,
) => DefaultSeedDoc(codec.collection, codec.idOf(record), codec.toRow(record));

/// What seeding writes, given whether each default document exists: true,
/// false, or null when it can't be told (offline, and not in the cache).
@immutable
class DefaultsSeedPlan {
  const DefaultsSeedPlan({required this.create, required this.complete});

  /// Indexes of the documents to create: only ones known to be missing, so
  /// an existing profile or a budget set on a default is never overwritten.
  final List<int> create;

  /// Whether every document exists once [create] is written. Otherwise the
  /// rest waits for the next run (`DefaultsSeedMarker` stays unset).
  final bool complete;
}

DefaultsSeedPlan planDefaultsSeed(List<bool?> exists) => DefaultsSeedPlan(
  create: [
    for (var i = 0; i < exists.length; i++)
      if (exists[i] == false) i,
  ],
  complete: !exists.contains(null),
);

/// Creates the default documents an account is missing. Online, they are
/// checked again and created in one transaction, so a default created
/// meanwhile (a budget set on it, here or on another device) is never
/// replaced. Offline (and for a brand-new account) they go in one batch
/// handed to the Firestore SDK, which applies it to the device cache at once
/// and uploads it when online, so seeding works offline.
class DefaultsSeeder {
  /// [firestore] defaults to the app's; [exists] replaces the existence
  /// lookup in tests.
  DefaultsSeeder({
    FirebaseFirestore? firestore,
    Future<bool?> Function(DocumentReference<Map<String, dynamic>> doc)? exists,
    this.serverTimeout = const Duration(seconds: 10),
  }) : _firestore = firestore,
       _exists = exists;

  final FirebaseFirestore? _firestore;
  final Future<bool?> Function(DocumentReference<Map<String, dynamic>> doc)?
  _exists;

  /// How long to wait for the server when the cache doesn't have a document.
  final Duration serverTimeout;

  /// Writes whichever of [docs] are missing for [uid]. A brand-new account
  /// ([isNewUser]) has none yet, so nothing is looked up. Returns whether
  /// every document is now known to exist.
  Future<bool> seed(
    String uid,
    List<DefaultSeedDoc> docs, {
    bool isNewUser = false,
  }) async {
    final firestore = _firestore ?? FirebaseBackend.firestore;
    final root = firestore.collection('users').doc(uid);
    final refs = [
      for (final doc in docs) root.collection(doc.collection).doc(doc.id),
    ];
    final exists = isNewUser
        ? List<bool?>.filled(docs.length, false)
        : await Future.wait(refs.map(_exists ?? documentExists));
    final plan = planDefaultsSeed(exists);
    if (plan.create.isEmpty) return plan.complete;
    // The server said these are missing, so it is likely reachable.
    if (!isNewUser && await _createInTransaction(firestore, refs, docs, plan)) {
      return plan.complete;
    }
    // Offline: skip any created on this device since it was looked up (a
    // budget saved meanwhile). Nothing is awaited between this check and
    // handing the batch over, so a later save also reaches the SDK later.
    final missing = isNewUser
        ? plan.create
        : [
            for (final (i, cached) in (await Future.wait([
              for (final index in plan.create) _isCached(refs[index]),
            ])).indexed)
              if (!cached) plan.create[i],
          ];
    if (missing.isEmpty) return plan.complete;
    final batch = firestore.batch();
    for (final index in missing) {
      batch.set(refs[index], docs[index].row);
    }
    await OfflineStore.acceptWrite(batch.commit());
    return plan.complete;
  }

  /// Creates the planned documents that are still missing in one
  /// transaction. False when it couldn't run (offline, or no answer in
  /// [serverTimeout]); nothing was written then.
  Future<bool> _createInTransaction(
    FirebaseFirestore firestore,
    List<DocumentReference<Map<String, dynamic>>> refs,
    List<DefaultSeedDoc> docs,
    DefaultsSeedPlan plan,
  ) async {
    try {
      await firestore.runTransaction<void>((transaction) async {
        final snapshots = [
          for (final index in plan.create) await transaction.get(refs[index]),
        ];
        for (final (i, snapshot) in snapshots.indexed) {
          if (snapshot.exists) continue;
          final index = plan.create[i];
          transaction.set(refs[index], docs[index].row);
        }
      }, timeout: serverTimeout);
      return true;
    } catch (error) {
      debugPrint('[auth] seeding in a transaction failed: $error');
      return false;
    }
  }

  /// Whether this device has [doc] (cached, or being created here).
  static Future<bool> _isCached(
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    try {
      return (await doc.get(const GetOptions(source: Source.cache))).exists;
    } catch (_) {
      return false;
    }
  }

  /// Whether [doc] exists: true when this device has it (cached, or being
  /// created here), otherwise what the server says, or null when the server
  /// can't be reached in [serverTimeout].
  Future<bool?> documentExists(
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    try {
      final cached = await doc.get(const GetOptions(source: Source.cache));
      if (cached.exists) return true;
    } catch (_) {
      // Not in the cache.
    }
    try {
      final remote = await doc
          .get(const GetOptions(source: Source.server))
          .timeout(serverTimeout);
      return remote.exists;
    } catch (_) {
      return null;
    }
  }
}
