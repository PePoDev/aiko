import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aiko/core/offline/offline_user_context.dart';
import 'package:aiko/core/storage/file_sync_queue.dart';
import 'package:aiko/core/storage/local_file_cache.dart';
import 'package:aiko/features/transactions/data/transaction_attachment_repository.dart';
import 'package:aiko/features/transactions/domain/transaction_attachment.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show CollectionReference;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/storage/file_store_harness.dart';

const _guest = 'local:guest';
const _uid = 'uid-1';

/// The signed-in user, or the guest owner when signed out.
class _Owner implements OfflineUserContext {
  _Owner(this.signedIn);

  final String? Function() signedIn;

  @override
  Future<String> resolveUserId() async => signedIn() ?? _guest;
}

/// Storage whose uploads wait until [release] completes.
class _SlowRemote extends FakeRemoteFileStore {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> put(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.put(path, bytes, contentType: contentType);
  }
}

void main() {
  late Database db;
  late FakeFirebaseFirestore firestore;
  late FakeRemoteFileStore remote;
  late FileSyncQueue queue;
  late TransactionAttachmentRepository repository;
  String? signedIn;

  TransactionAttachmentRepository build(FakeRemoteFileStore files) {
    remote = files;
    queue = testQueue(files, signedInUserId: () => signedIn);
    return TransactionAttachmentRepository(
      userContext: _Owner(() => signedIn),
      firestore: firestore,
      signedInUserId: () => signedIn,
      queue: queue,
    )..registerUploads();
  }

  setUp(() async {
    db = await openMemoryFileCache();
    firestore = FakeFirebaseFirestore();
    signedIn = null;
    repository = build(FakeRemoteFileStore());
  });

  tearDown(() async {
    await queue.dispose();
    await closeMemoryFileCache(db);
  });

  Future<TransactionAttachment> attachment(
    String id, {
    String transactionId = 'tx-1',
    List<int> bytes = const [1, 2, 3],
  }) async => TransactionAttachment(
    id: id,
    userId: '',
    transactionId: transactionId,
    fileName: '$id.jpg',
    storagePath: await LocalFileCache.write('attachments/$id', bytes),
    mimeType: 'image/jpeg',
    sizeBytes: bytes.length,
    createdAt: DateTime.utc(2026, 10, 1),
  );

  CollectionReference<Map<String, dynamic>> cloudRows() =>
      firestore.collection('users').doc(_uid).collection('attachments');

  /// The Firestore row of an attachment another device uploaded.
  Map<String, dynamic> cloudRow(String id, String path) => {
    'created_at': '2026-09-01T00:00:00.000Z',
    'id': id,
    'user_id': _uid,
    'storage_bucket': 'receipts',
    'storage_path': path,
    'file_name': path.split('/').last,
    'content_type': 'application/pdf',
    'size_bytes': 5,
    'linked_entity_type': 'transaction',
    'linked_entity_id': 'tx-1',
    'is_sensitive': false,
    'export_policy': 'include',
  };

  group('signed out', () {
    test('attachments stay on the device and nothing is queued', () async {
      final saved = await repository.save(await attachment('a1'));

      expect(saved.userId, _guest);
      expect(saved.storagePath, 'aiko-cache:attachments/a1');
      expect(await queue.pending(), isEmpty);
      final listed = await repository.listForTransaction('tx-1');
      expect(listed.single.id, 'a1');
      expect(await repository.readBytes(listed.single), [1, 2, 3]);
      expect((await cloudRows().get()).docs, isEmpty);
    });

    test('metadata survives a new repository', () async {
      await repository.save(await attachment('a1'));

      final reopened = TransactionAttachmentRepository(
        userContext: _Owner(() => null),
        firestore: firestore,
        signedInUserId: () => null,
        queue: queue,
      );
      expect((await reopened.listForTransaction('tx-1')).single.id, 'a1');
      expect(await reopened.listForTransaction('tx-2'), isEmpty);
    });

    test('a picker file is copied into the cache on save', () async {
      final dir = Directory.systemTemp.createTempSync('aiko_attach');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/scan.jpg')..writeAsBytesSync([7, 8]);
      final picked = (await attachment('a1')).copyWith(storagePath: file.path);

      final saved = await repository.save(picked);
      file.deleteSync();

      expect(saved.storagePath, startsWith(LocalFileCache.pathPrefix));
      expect(await repository.readBytes(saved), [7, 8]);
    });

    test('rejects attachments over the upload limit', () async {
      final big = (await attachment('a1')).copyWith();
      final tooBig = TransactionAttachment(
        id: big.id,
        userId: '',
        transactionId: 'tx-1',
        fileName: big.fileName,
        storagePath: big.storagePath,
        mimeType: big.mimeType,
        sizeBytes: TransactionAttachment.maxUploadBytes + 1,
        createdAt: big.createdAt,
      );
      await expectLater(repository.save(tooBig), throwsArgumentError);
    });

    test('delete removes the metadata and the cached bytes', () async {
      final saved = await repository.save(await attachment('a1'));

      await repository.delete(saved);

      expect(await repository.listForTransaction('tx-1'), isEmpty);
      expect(await LocalFileCache.contains(saved.storagePath), isFalse);
      expect(await queue.pending(), isEmpty);
    });
  });

  group('signed in', () {
    setUp(() => signedIn = _uid);

    test('save returns at once and queues the upload', () async {
      final saved = await repository.save(await attachment('a1'));

      expect(saved.userId, _uid);
      expect(saved.storagePath, 'aiko-cache:attachments/a1');
      expect(remote.calls, isEmpty);
      expect((await cloudRows().get()).docs, isEmpty);
      final job = (await queue.pending()).single;
      expect(job.id, TransactionAttachmentRepository.uploadJobId('a1'));
      expect(job.ownerId, _uid);
      // Visible right away, waiting to upload.
      expect(
        (await repository.listForTransaction('tx-1')).single.storagePath,
        saved.storagePath,
      );
    });

    test('the upload stores the file, then the cloud metadata', () async {
      await repository.save(await attachment('a1'));

      await queue.process();

      const cloudPath = 'users/$_uid/receipts/a1/a1.jpg';
      expect(remote.files[cloudPath], [1, 2, 3]);
      expect(remote.contentTypes[cloudPath], 'image/jpeg');
      final row = (await cloudRows().doc('a1').get()).data()!;
      expect(row['storage_path'], cloudPath);
      expect(row['user_id'], _uid);
      expect(row['linked_entity_id'], 'tx-1');
      expect(await queue.pending(), isEmpty);

      final listed = await repository.listForTransaction('tx-1');
      expect(listed.single.storagePath, cloudPath);
      // The device keeps the bytes: opening it needs no download.
      remote.failure = FakeRemoteFileStore.offline;
      expect(await repository.readBytes(listed.single), [1, 2, 3]);
      expect(remote.calls, ['put $cloudPath']);
      expect(
        await LocalFileCache.contains('aiko-cache:attachments/a1'),
        isFalse,
      );
    });

    test('offline, the upload waits and runs when back online', () async {
      remote.failure = FakeRemoteFileStore.offline;
      await repository.save(await attachment('a1'));

      await queue.process();
      expect(await queue.pendingCount(_uid), 1);
      expect(
        (await repository.listForTransaction('tx-1')).single.storagePath,
        'aiko-cache:attachments/a1',
      );

      remote.failure = null;
      await queue.process();
      expect(await queue.pendingCount(_uid), 0);
      expect(
        (await repository.listForTransaction('tx-1')).single.storagePath,
        'users/$_uid/receipts/a1/a1.jpg',
      );
    });

    test('running the upload again changes nothing', () async {
      await repository.save(await attachment('a1'));
      final job = (await queue.pending()).single;
      await queue.process();

      // The same job again, as after a crash before it was removed.
      await queue.enqueue(job);
      await queue.process();

      expect(remote.calls, ['put users/$_uid/receipts/a1/a1.jpg']);
      expect((await repository.listForTransaction('tx-1')).length, 1);
    });

    test('deleting before the upload queues no upload', () async {
      final saved = await repository.save(await attachment('a1'));

      await repository.delete(saved);

      expect(await repository.listForTransaction('tx-1'), isEmpty);
      final jobs = await queue.pending();
      expect(jobs.single.kind, FileSyncQueue.deleteKind);
      await queue.process();
      expect(remote.files, isEmpty);
      expect(remote.calls, ['delete users/$_uid/receipts/a1/a1.jpg']);
    });

    test('deleting an uploaded attachment, offline, is queued', () async {
      await repository.save(await attachment('a1'));
      await queue.process();
      final uploaded = (await repository.listForTransaction('tx-1')).single;
      remote.failure = FakeRemoteFileStore.offline;

      await repository.delete(uploaded);

      expect((await cloudRows().doc('a1').get()).exists, isFalse);
      expect(await repository.listForTransaction('tx-1'), isEmpty);
      await queue.process();
      expect(remote.files, isNotEmpty);

      remote.failure = null;
      await queue.process();
      expect(remote.files, isEmpty);
      expect(await queue.pending(), isEmpty);
    });

    test('a delete during the upload wins', () async {
      final slow = _SlowRemote();
      repository = build(slow);
      final saved = await repository.save(await attachment('a1'));

      final pass = queue.process();
      await slow.started.future;
      await repository.delete(saved);
      slow.release.complete();
      await pass;
      await queue.process();

      expect((await cloudRows().doc('a1').get()).exists, isFalse);
      expect(slow.files, isEmpty);
      expect(await repository.listForTransaction('tx-1'), isEmpty);
      expect(await queue.pending(), isEmpty);
    });

    test('an attachment whose bytes are gone is dropped', () async {
      final saved = await repository.save(await attachment('a1'));
      await LocalFileCache.remove(saved.storagePath);

      await queue.process();

      expect(remote.calls, isEmpty);
      expect(await repository.listForTransaction('tx-1'), isEmpty);
      expect(await queue.pending(), isEmpty);
    });

    test('opening downloads once, and says so when offline', () async {
      const path = 'users/$_uid/receipts/r9/r9.pdf';
      remote.files[path] = Uint8List.fromList([4, 2]);
      final cloud = TransactionAttachment(
        id: 'r9',
        userId: _uid,
        transactionId: 'tx-1',
        fileName: 'r9.pdf',
        storagePath: path,
        mimeType: 'application/pdf',
        sizeBytes: 2,
        createdAt: DateTime.utc(2026),
      );
      final missing = TransactionAttachment(
        id: 'r8',
        userId: _uid,
        transactionId: 'tx-1',
        fileName: 'r8.pdf',
        storagePath: 'users/$_uid/receipts/r8/r8.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 2,
        createdAt: DateTime.utc(2026),
      );

      expect(await repository.readBytes(cloud), [4, 2]);
      remote.failure = FakeRemoteFileStore.offline;
      expect(await repository.readBytes(cloud), [4, 2]);
      expect(remote.calls, ['get $path']);

      await expectLater(
        repository.readBytes(missing),
        throwsA(
          isA<AttachmentUnavailableException>().having(
            (error) => error.offline,
            'offline',
            isTrue,
          ),
        ),
      );
      remote.failure = null;
      await expectLater(
        repository.readBytes(missing),
        throwsA(
          isA<AttachmentUnavailableException>().having(
            (error) => error.offline,
            'offline',
            isFalse,
          ),
        ),
      );
    });

    test('lists other devices\' attachments with the waiting ones', () async {
      await cloudRows().doc('other').set({
        'created_at': '2026-09-01T00:00:00.000Z',
        'id': 'other',
        'user_id': _uid,
        'storage_bucket': 'receipts',
        'storage_path': 'users/$_uid/receipts/other/other.pdf',
        'file_name': 'other.pdf',
        'content_type': 'application/pdf',
        'size_bytes': 5,
        'linked_entity_type': 'transaction',
        'linked_entity_id': 'tx-1',
        'is_sensitive': false,
        'export_policy': 'include',
      });
      await repository.save(await attachment('a1'));

      final listed = await repository.listForTransaction('tx-1');

      expect(listed.map((item) => item.id), ['other', 'a1']);
    });

    test('watching follows the upload', () async {
      final updates = <List<String>>[];
      final subscription = repository
          .watchForTransaction('tx-1')
          .listen(
            (items) => updates.add([for (final i in items) i.storagePath]),
          );
      await repository.save(await attachment('a1'));
      await pumpEventQueue();
      await queue.process();
      await pumpEventQueue();
      await subscription.cancel();

      expect(updates.first, isEmpty);
      expect(updates, anyElement(equals(['aiko-cache:attachments/a1'])));
      expect(updates.last, ['users/$_uid/receipts/a1/a1.jpg']);
    });

    test('deleting a transaction\'s attachments queues their files', () async {
      await repository.save(await attachment('a1'));
      await repository.save(await attachment('a2', transactionId: 'tx-2'));
      await queue.process();

      await repository.deleteForTransactions(['tx-1', 'tx-2']);
      // The cleanup, then the Storage deletes it queued.
      await queue.process();
      await queue.process();

      expect(remote.files, isEmpty);
      expect((await cloudRows().get()).docs, isEmpty);
      expect(await repository.listForTransaction('tx-1'), isEmpty);
      expect(await repository.listForTransaction('tx-2'), isEmpty);
      expect(await queue.pending(), isEmpty);
    });

    test('deleting a transaction offline finds its cloud attachments once '
        'online, even ones this device never listed', () async {
      const path = 'users/$_uid/receipts/web/web.pdf';
      remote.files[path] = Uint8List.fromList([1]);
      await cloudRows().doc('web').set(cloudRow('web', path));
      // Waiting on this device: goes at once.
      await repository.save(await attachment('a1'));

      remote.failure = FakeRemoteFileStore.offline;
      await repository.deleteForTransactions(['tx-1']);
      expect(
        await LocalFileCache.contains('aiko-cache:attachments/a1'),
        isFalse,
      );
      await queue.process();
      expect(remote.files, isNotEmpty);

      remote.failure = null;
      await queue.process();
      await queue.process();
      expect(remote.files, isEmpty);
      expect((await cloudRows().get()).docs, isEmpty);
      expect(await queue.pending(), isEmpty);
    });

    test('a sign-out during the upload keeps the attachment and its upload '
        'for the owner', () async {
      final slow = _SlowRemote();
      repository = build(slow);
      await repository.save(await attachment('a1'));

      final pass = queue.process();
      await slow.started.future;
      signedIn = null; // Log out while the file uploads.
      slow.release.complete();
      await pass;

      // Nothing was written as someone else; the device copy is kept.
      expect((await cloudRows().get()).docs, isEmpty);
      final job = (await queue.pending()).single;
      expect(job.ownerId, _uid);
      expect(job.attempts, 0);
      final rows = await db.query('attachments');
      expect(rows.single['owner_id'], _uid);

      signedIn = _uid;
      await queue.process();
      expect(
        (await cloudRows().doc('a1').get()).data()!['storage_path'],
        'users/$_uid/receipts/a1/a1.jpg',
      );
      expect(await db.query('attachments'), isEmpty);
    });

    test('an upload that fails for good says so and can be retried', () async {
      final saved = await repository.save(await attachment('a1'));
      expect(await repository.uploadStalled(saved), isFalse);

      remote.failure = StateError('rejected');
      for (var i = 0; i < FileSyncQueue.maxAttempts; i++) {
        await queue.process();
      }
      expect(await repository.uploadStalled(saved), isTrue);
      // Still waiting on this device, not lost.
      expect(
        (await repository.listForTransaction('tx-1')).single.storagePath,
        saved.storagePath,
      );

      remote.failure = null;
      await repository.retryUpload(saved);
      expect(await repository.uploadStalled(saved), isFalse);
      await queue.process();
      expect(remote.files.keys, ['users/$_uid/receipts/a1/a1.jpg']);
      expect(await repository.uploadStalled(saved), isFalse);
    });

    test('an attachment left without its upload is queued again at the next '
        'launch', () async {
      final dir = Directory.systemTemp.createTempSync('aiko_stranded');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/${LocalFileCache.fileName}';
      final jobId = TransactionAttachmentRepository.uploadJobId('a1');
      var launch = await LocalFileCache.openAt(
        path,
        factory: databaseFactoryFfiNoIsolate,
      );
      LocalFileCache.useDatabase(launch);
      final saved = await repository.save(await attachment('a1'));
      // What earlier versions left after dropping a failing upload.
      await queue.remove(jobId);
      expect(await repository.uploadStalled(saved), isTrue);

      // The next launch opens the database again.
      await launch.close();
      launch = await LocalFileCache.openAt(
        path,
        factory: databaseFactoryFfiNoIsolate,
      );
      LocalFileCache.useDatabase(launch);
      expect(await repository.listForTransaction('tx-1'), hasLength(1));
      expect(await queue.job(jobId), isNotNull);

      await queue.process();
      expect(remote.files.keys, ['users/$_uid/receipts/a1/a1.jpg']);
      LocalFileCache.useDatabase(db);
      await launch.close();
    });

    test(
      'forgetOwner drops the device rows and copies of that user only',
      () async {
        await repository.save(await attachment('a1'));
        await repository.save(await attachment('a2'));
        await queue.process(); // a1 and a2 uploaded; copies kept.
        await repository.save(await attachment('a3')); // Still waiting.
        await LocalFileCache.write('receipts/users/uid-2/receipts/x/x.jpg', [
          1,
        ]);

        await repository.forgetOwner(_uid);

        expect(await db.query('attachments'), isEmpty);
        final kept = await db.query('files', columns: ['path']);
        expect(kept.map((row) => row['path']), [
          'aiko-cache:receipts/users/uid-2/receipts/x/x.jpg',
        ]);
      },
    );
  });

  test('guest attachments are claimed and uploaded after sign-in', () async {
    await repository.save(await attachment('a1'));
    expect(await queue.pending(), isEmpty);

    signedIn = _uid;
    expect(await repository.claimGuestAttachments(_uid), 1);
    expect(await repository.claimGuestAttachments(_uid), 0);
    expect((await queue.pending()).single.ownerId, _uid);

    await queue.process();
    expect(remote.files.keys, ['users/$_uid/receipts/a1/a1.jpg']);
    expect((await cloudRows().doc('a1').get()).data()!['user_id'], _uid);
  });

  test('claiming for a guest owner does nothing', () async {
    await repository.save(await attachment('a1'));
    expect(await repository.claimGuestAttachments('local:other'), 0);
  });

  test('imports the previous version\'s metadata once', () async {
    Map<String, dynamic> row(String id, String path) => {
      'created_at': '2026-05-19T00:00:00.000Z',
      'id': id,
      'user_id': '',
      'storage_bucket': 'receipts',
      'storage_path': path,
      'file_name': '$id.jpg',
      'content_type': 'image/jpeg',
      'size_bytes': 3,
      'linked_entity_type': 'transaction',
      'linked_entity_id': 'tx-1',
      'is_sensitive': false,
      'export_policy': 'include',
    };
    await LocalFileCache.write('attachments/waiting', [1, 2, 3]);
    await LocalFileCache.write(
      'attachment-metadata/$_uid/tx-1',
      utf8.encode(
        jsonEncode([
          row('uploaded', 'users/$_uid/receipts/uploaded/uploaded.jpg'),
          row('waiting', 'aiko-cache:attachments/waiting'),
        ]),
      ),
    );
    await LocalFileCache.write(
      'attachment-metadata/$_guest/tx-1',
      utf8.encode(jsonEncode([row('guest', 'aiko-cache:attachments/g')])),
    );

    // Signed out: the guest's attachment is there.
    expect(
      (await repository.listForTransaction('tx-1')).map((item) => item.id),
      ['guest'],
    );
    expect(
      await LocalFileCache.contains(
        'aiko-cache:attachment-metadata/$_uid/tx-1',
      ),
      isFalse,
    );
    // The signed-in user's unsent upload is queued; the uploaded one is
    // left to Firestore.
    final job = (await queue.pending()).single;
    expect(job.id, TransactionAttachmentRepository.uploadJobId('waiting'));
    expect(job.ownerId, _uid);

    signedIn = _uid;
    await queue.process();
    expect(remote.files.keys, ['users/$_uid/receipts/waiting/waiting.jpg']);
  });
}
