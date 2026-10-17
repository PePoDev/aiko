import 'package:aiko/core/offline/records/records.dart';
import 'package:aiko/features/auth/data/defaults_seeder.dart';
import 'package:aiko/features/categories/domain/category_defaults.dart';
import 'package:aiko/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const uid = 'user-1';
  const email = 'ann@example.com';
  final defaultCount =
      1 + CategoryGroupDefaults.all.length + CategoryDefaults.all.length;

  CollectionReference<Map<String, dynamic>> collection(
    FakeFirebaseFirestore firestore,
    String name,
  ) => firestore.collection('users').doc(uid).collection(name);

  Future<int> storedCount(FakeFirebaseFirestore firestore) async {
    var count = 0;
    for (final name in ['profiles', 'category_groups', 'categories']) {
      count += (await collection(firestore, name).get()).size;
    }
    return count;
  }

  group('defaultSeedDocs', () {
    test('a profile and one clone per default group and category', () {
      final docs = defaultSeedDocs(uid, email);

      expect(docs, hasLength(defaultCount));
      expect(docs.first.collection, 'profiles');
      expect(docs.first.id, uid);
      expect(docs.first.row['display_name'], 'ann');
      expect(docs.first.row['email'], email);
      expect(
        docs.map((doc) => '${doc.collection}/${doc.id}').toSet(),
        hasLength(defaultCount),
      );
    });

    test('uses the ids older versions seeded, the same on every device', () {
      final docs = defaultSeedDocs(uid, email);
      final again = defaultSeedDocs(uid, email);

      expect(
        [for (final doc in docs) doc.id],
        [for (final doc in again) doc.id],
      );
      final template = CategoryDefaults.all.first;
      final categoryIds = {
        for (final doc in docs)
          if (doc.collection == 'categories') doc.id,
      };
      expect(
        categoryIds,
        contains(
          CategoryDefaults.cloneIdForUser(userId: uid, templateId: template.id),
        ),
      );
      final group = CategoryGroupDefaults.all.first;
      expect(
        docs
            .where((doc) => doc.collection == 'category_groups')
            .map((doc) => doc.id),
        contains(
          CategoryGroupDefaults.cloneIdForUser(
            userId: uid,
            templateId: group.id,
          ),
        ),
      );
      // Rows are the codec rows, owned by the user.
      for (final doc in docs.skip(1)) {
        expect(doc.row['user_id'], uid);
        expect(doc.row['id'], doc.id);
        expect(doc.row['template_id'], isNotNull);
      }
    });

    test('a new account takes the guest profile under its own id', () {
      final guest = OfflineProfile(
        id: 'local:abc',
        displayName: 'Nok',
        email: '',
        baseCurrency: 'USD',
        country: 'US',
        preferredTheme: 'dark',
      );

      final profile = defaultSeedDocs(uid, email, guestProfile: guest).first;

      expect(profile.id, uid);
      expect(profile.row['id'], uid);
      expect(profile.row['email'], email);
      expect(profile.row['display_name'], 'Nok');
      expect(profile.row['base_currency'], 'USD');
      expect(profile.row['preferred_theme'], 'dark');
    });

    test('a guest who never named themselves gets the email name', () {
      final placeholders = [
        for (final locale in AppLocalizations.supportedLocales)
          lookupAppLocalizations(locale).profileDefaultDisplayName,
        '  ',
      ];
      for (final placeholder in placeholders) {
        final guest = OfflineProfile(
          id: 'local:abc',
          displayName: placeholder,
          email: '',
          baseCurrency: 'THB',
          country: 'TH',
        );
        expect(
          defaultSeedDocs(
            uid,
            email,
            guestProfile: guest,
          ).first.row['display_name'],
          'ann',
          reason: placeholder,
        );
      }
    });
  });

  group('planDefaultsSeed', () {
    test('creates only documents known to be missing', () {
      final plan = planDefaultsSeed([true, false, null, false]);

      expect(plan.create, [1, 3]);
      expect(plan.complete, isFalse);
    });

    test('is complete when every document is known', () {
      final plan = planDefaultsSeed([true, false, true]);

      expect(plan.create, [1]);
      expect(plan.complete, isTrue);
      expect(planDefaultsSeed([true, true]).create, isEmpty);
    });
  });

  group('DefaultsSeeder', () {
    late FakeFirebaseFirestore firestore;

    setUp(() => firestore = FakeFirebaseFirestore());

    test('creates every default for an account that has none', () async {
      final complete = await DefaultsSeeder(
        firestore: firestore,
      ).seed(uid, defaultSeedDocs(uid, email));
      await pumpEventQueue();

      expect(complete, isTrue);
      expect(await storedCount(firestore), defaultCount);
    });

    test('seeding again (or on another device) duplicates nothing and keeps '
        'budgets and the profile', () async {
      final seeder = DefaultsSeeder(firestore: firestore);
      await seeder.seed(uid, defaultSeedDocs(uid, email));
      await pumpEventQueue();
      final cloneId = CategoryDefaults.cloneIdForUser(
        userId: uid,
        templateId: CategoryDefaults.all.first.id,
      );
      await collection(
        firestore,
        'categories',
      ).doc(cloneId).update({'budget_amount': '500', 'budget_currency': 'THB'});
      await collection(
        firestore,
        'profiles',
      ).doc(uid).update({'display_name': 'Ann B.', 'base_currency': 'EUR'});

      final complete = await seeder.seed(uid, defaultSeedDocs(uid, email));
      await pumpEventQueue();

      expect(complete, isTrue);
      expect(await storedCount(firestore), defaultCount);
      final clone = await collection(
        firestore,
        'categories',
      ).doc(cloneId).get();
      expect(clone['budget_amount'], '500');
      final profile = await collection(firestore, 'profiles').doc(uid).get();
      expect(profile['display_name'], 'Ann B.');
      expect(profile['base_currency'], 'EUR');
    });

    test('leaves documents seeded the old way untouched', () async {
      final docs = defaultSeedDocs(uid, email);
      for (final doc in docs) {
        await collection(
          firestore,
          doc.collection,
        ).doc(doc.id).set({...doc.row, 'updated_at': 'old'});
      }

      final complete = await DefaultsSeeder(
        firestore: firestore,
      ).seed(uid, defaultSeedDocs(uid, email));
      await pumpEventQueue();

      expect(complete, isTrue);
      final rows = await collection(firestore, 'categories').get();
      expect(rows.docs.map((doc) => doc['updated_at']).toSet(), {'old'});
    });

    test('only adds the defaults that are missing', () async {
      final docs = defaultSeedDocs(uid, email);
      final profile = docs.first;
      await collection(
        firestore,
        'profiles',
      ).doc(uid).set({...profile.row, 'display_name': 'Kept'});

      await DefaultsSeeder(firestore: firestore).seed(uid, docs);
      await pumpEventQueue();

      expect(await storedCount(firestore), defaultCount);
      final stored = await collection(firestore, 'profiles').doc(uid).get();
      expect(stored['display_name'], 'Kept');
    });

    test('offline, writes only what it knows is missing and reports the run '
        'incomplete', () async {
      final docs = defaultSeedDocs(uid, email);
      final missingId = docs[1].id;
      // The cache only knows one group is missing; nothing else can be told.
      final seeder = DefaultsSeeder(
        firestore: firestore,
        exists: (doc) async => doc.id == missingId ? false : null,
      );

      final complete = await seeder.seed(uid, docs);
      await pumpEventQueue();

      expect(complete, isFalse);
      expect(await storedCount(firestore), 1);
      expect(
        (await collection(
          firestore,
          docs[1].collection,
        ).doc(missingId).get()).exists,
        isTrue,
      );
    });

    test('a new account is seeded without looking anything up', () async {
      var lookups = 0;
      final seeder = DefaultsSeeder(
        firestore: firestore,
        exists: (doc) async {
          lookups++;
          return null;
        },
      );

      final complete = await seeder.seed(
        uid,
        defaultSeedDocs(uid, email),
        isNewUser: true,
      );
      await pumpEventQueue();

      expect(complete, isTrue);
      expect(lookups, 0);
      expect(await storedCount(firestore), defaultCount);
    });

    test(
      'a document the device has counts as existing without the server',
      () async {
        final seeder = DefaultsSeeder(
          firestore: firestore,
          serverTimeout: const Duration(milliseconds: 50),
        );
        final ref = collection(firestore, 'profiles').doc(uid);
        expect(await seeder.documentExists(ref), isFalse);
        await ref.set({'id': uid});
        expect(await seeder.documentExists(ref), isTrue);
      },
    );
  });
}
