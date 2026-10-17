import 'dart:io';

import 'package:aiko/core/offline/record_batch.dart';
import 'package:aiko/core/storage/local_record_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../offline/record_store_harness.dart';

RecordWrite put(String id, {String owner = 'owner', int value = 1}) =>
    RecordWrite.put(
      collection: 'things',
      id: id,
      ownerId: owner,
      row: {'id': id, 'user_id': owner, 'value': value},
    );

void main() {
  late LocalRecordStore store;

  setUp(() async => store = await openMemoryRecordStore());
  tearDown(() => store.close());

  test('stores rows as JSON and filters by owner and id', () async {
    await store.apply([
      put('a'),
      put('b', owner: 'other'),
      RecordWrite.put(
        collection: 'others',
        id: 'a',
        ownerId: 'owner',
        row: {
          'id': 'a',
          'nested': {
            'list': [1, 'two', null],
          },
        },
      ),
    ]);

    expect(await store.rows('things'), hasLength(2));
    expect(await store.rows('things', ownerId: 'owner'), [
      {'id': 'a', 'user_id': 'owner', 'value': 1},
    ]);
    expect(await store.rows('things', id: 'b'), [
      {'id': 'b', 'user_id': 'other', 'value': 1},
    ]);
    expect((await store.rows('others')).single['nested'], {
      'list': [1, 'two', null],
    });
  });

  test('a put replaces the record with the same collection and id', () async {
    await store.apply([put('a', value: 1)]);
    await store.apply([put('a', value: 2)]);

    expect(await store.rows('things'), [
      {'id': 'a', 'user_id': 'owner', 'value': 2},
    ]);
  });

  test(
    'deletes only the given owner\'s record when an owner is given',
    () async {
      await store.apply([put('a'), put('b')]);

      await store.apply([
        const RecordWrite.delete(collection: 'things', id: 'a', ownerId: 'x'),
      ]);
      expect(await store.rows('things'), hasLength(2));

      await store.apply([
        const RecordWrite.delete(
          collection: 'things',
          id: 'a',
          ownerId: 'owner',
        ),
        const RecordWrite.delete(collection: 'things', id: 'b'),
      ]);
      expect(await store.rows('things'), isEmpty);
    },
  );

  test('a failing batch leaves nothing behind', () async {
    await store.apply([put('kept')]);

    await expectLater(
      store.transaction((txn) async {
        await txn.write(put('lost'));
        await txn.write(
          const RecordWrite.delete(collection: 'things', id: 'kept'),
        );
        throw StateError('boom');
      }),
      throwsStateError,
    );

    expect((await store.rows('things')).map((row) => row['id']), ['kept']);
  });

  test('put without replace keeps the existing record', () async {
    await store.apply([put('a', value: 1)]);
    await store.transaction((txn) async {
      await txn.put('things', 'a', 'owner', {
        'id': 'a',
        'value': 9,
      }, replace: false);
      await txn.setMeta('marker', 'done');
    });

    expect((await store.rows('things')).single['value'], 1);
    expect(await store.meta('marker'), 'done');
    expect(await store.meta('missing'), isNull);
  });

  test('a new database file gets the schema version', () async {
    final dir = await Directory.systemTemp.createTemp('aiko-records-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/${LocalRecordStore.fileName}';
    final fileStore = await LocalRecordStore.openAt(
      path,
      factory: databaseFactoryFfiNoIsolate,
    );
    await fileStore.apply([put('a')]);
    await fileStore.close();

    final raw = await databaseFactoryFfiNoIsolate.openDatabase(path);
    expect(await raw.getVersion(), LocalRecordStore.schemaVersion);
    await raw.close();
    final reopened = await LocalRecordStore.openAt(
      path,
      factory: databaseFactoryFfiNoIsolate,
    );
    addTearDown(reopened.close);
    expect(await reopened.rows('things'), hasLength(1));
  });
}
