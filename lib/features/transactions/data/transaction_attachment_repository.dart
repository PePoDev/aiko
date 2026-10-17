import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart'
    show ConflictAlgorithm, Database, DatabaseExecutor;

import '../../../core/firebase/firebase_backend.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/offline/offline_user_context.dart';
import '../../../core/storage/file_sync_queue.dart';
import '../../../core/storage/local_file_cache.dart';
import '../../../core/storage/remote_file_store.dart';
import '../domain/transaction_attachment.dart';

/// An attachment could not be opened: its bytes are not on this device and
/// could not be downloaded.
class AttachmentUnavailableException implements Exception {
  const AttachmentUnavailableException({required this.offline});

  /// The download failed for want of a connection; it should work online.
  final bool offline;

  @override
  String toString() => 'AttachmentUnavailableException(offline: $offline)';
}

/// Transaction attachments: bytes in [LocalFileCache], metadata in Firestore
/// `attachments` (signed in) or on this device (guests and local-only
/// builds), files in Firebase Storage.
///
/// Saving never waits for the network. The bytes and the metadata (with the
/// device path) are stored on the device at once and, signed in, an upload is
/// queued in [FileSyncQueue]. When it has run, the Firestore document is
/// written with the Storage path and the device row is dropped; the cached
/// bytes stay for offline viewing. Deleting works the same way: the metadata
/// goes at once and the Storage delete is queued.
class TransactionAttachmentRepository {
  /// [userContext], [firestore], [signedInUserId], [queue] and [remote]
  /// default to the app's; tests replace them.
  TransactionAttachmentRepository({
    OfflineUserContext? userContext,
    FirebaseFirestore? firestore,
    String? Function()? signedInUserId,
    FileSyncQueue? queue,
    RemoteFileStore? remote,
  }) : _userContext = userContext ?? OfflineUserContext(),
       _firestore = firestore,
       _signedInUserId = signedInUserId ?? (() => FirebaseBackend.userId),
       _queueOverride = queue,
       _remoteOverride = remote;

  final OfflineUserContext _userContext;
  final FirebaseFirestore? _firestore;
  final String? Function() _signedInUserId;
  final FileSyncQueue? _queueOverride;
  final RemoteFileStore? _remoteOverride;

  FileSyncQueue get _queue => _queueOverride ?? FileSyncQueue.instance;
  RemoteFileStore get _remoteFiles => _remoteOverride ?? _queue.remote;

  /// Queue job kind that uploads one attachment.
  static const uploadKind = 'attachment-upload';

  /// Device rows changed (saved, deleted, uploaded or claimed).
  static final _localChanges = StreamController<void>.broadcast();

  /// Upload jobs found in a database already imported, per database.
  static final _legacyImports = Expando<Future<void>>();

  /// Lets the queue run this repository's uploads.
  void registerUploads() => _queue.register(uploadKind, _upload);

  static String uploadJobId(String attachmentId) => 'attachment:$attachmentId';

  /// Where [attachment] lives in Firebase Storage once [userId] uploaded it.
  static String cloudPathFor(String userId, TransactionAttachment attachment) =>
      'users/$userId/receipts/${attachment.id}/${attachment.fileName}';

  /// The cache key that keeps a downloaded or uploaded copy of [cloudPath].
  static String _cacheKeyFor(String cloudPath) => 'receipts/$cloudPath';

  String? get _uid {
    final uid = _signedInUserId();
    return uid == null || uid.isEmpty ? null : uid;
  }

  /// Whether attachments are uploaded to the cloud (signed in); otherwise
  /// they stay on this device.
  bool get uploadsToCloud => _uid != null;

  CollectionReference<Map<String, dynamic>> _remote(String uid) =>
      (_firestore ?? FirebaseBackend.firestore)
          .collection('users')
          .doc(uid)
          .collection('attachments');

  Future<Database> _db() async {
    final db = await LocalFileCache.database();
    await (_legacyImports[db] ??= _importLegacy(db));
    return db;
  }

  /// Stores [attachment] for its transaction on this device and, signed in,
  /// queues its upload. Returns at once with the stored attachment.
  Future<TransactionAttachment> save(TransactionAttachment attachment) async {
    if (!attachment.isValidForUpload) {
      throw ArgumentError.value(
        attachment.fileName,
        'attachment',
        'Attachment metadata is invalid or unsupported',
      );
    }

    final userId = await _userContext.resolveUserId();
    var saved = attachment.copyWith(userId: userId);
    final uid = _uid;
    if (!LocalFileCache.isDevicePath(saved.storagePath)) {
      // Already in the cloud: only the metadata changes.
      if (uid != null) {
        await OfflineStore.acceptWrite(
          _remote(uid).doc(saved.id).set(_toRow(saved)),
        );
        return saved;
      }
    } else if (!saved.storagePath.startsWith(LocalFileCache.pathPrefix)) {
      // A picker file or web blob is temporary; keep a durable copy.
      saved = saved.copyWith(
        storagePath: await LocalFileCache.write(
          'attachments/${saved.id}',
          await LocalFileCache.read(saved.storagePath),
        ),
      );
    }
    final uploader = LocalFileCache.isDevicePath(saved.storagePath)
        ? uid
        : null;
    final db = await _db();
    await db.transaction((txn) async {
      await _putRow(txn, saved);
      if (uploader != null) {
        await _queue.enqueue(_uploadJob(uploader, saved.id), txn: txn);
      }
    });
    _localChanges.add(null);
    if (uploader != null) _queue.notifyChanged();
    return saved;
  }

  /// Deletes [attachment]: its metadata and cached bytes at once and, signed
  /// in, its Firestore document (through the SDK's queue) and a queued delete
  /// of the Storage file.
  Future<void> delete(TransactionAttachment attachment) async {
    final uid = _uid;
    final onDevice = LocalFileCache.isDevicePath(attachment.storagePath);
    // A waiting upload may already be running, so its file is deleted too.
    final cloudPath = onDevice
        ? (uid == null ? null : cloudPathFor(uid, attachment))
        : attachment.storagePath;
    final db = await _db();
    await db.transaction((txn) async {
      await txn.delete(
        'attachments',
        where: 'id = ?',
        whereArgs: [attachment.id],
      );
      await LocalFileCache.remove(attachment.storagePath, txn: txn);
      if (cloudPath != null) {
        await LocalFileCache.remove(
          '${LocalFileCache.pathPrefix}${_cacheKeyFor(cloudPath)}',
          txn: txn,
        );
      }
      await _queue.remove(uploadJobId(attachment.id), txn: txn);
      if (uid != null && cloudPath != null) {
        await _queue.enqueueDelete(uid, cloudPath, txn: txn);
      }
    });
    if (uid != null) {
      await OfflineStore.acceptWrite(_remote(uid).doc(attachment.id).delete());
    }
    _localChanges.add(null);
    _queue.notifyChanged();
  }

  /// Deletes every attachment of [transactionIds] (after the transactions
  /// were deleted). Never throws.
  Future<void> deleteForTransactions(Iterable<String> transactionIds) async {
    for (final transactionId in transactionIds) {
      try {
        for (final attachment in await listForTransaction(transactionId)) {
          await delete(attachment);
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[aiko-files] attachment cleanup failed: $error');
        }
      }
    }
  }

  /// The attachment's bytes: the device copy first, otherwise downloaded
  /// (signed in) and cached for next time. Throws
  /// [AttachmentUnavailableException] when neither works.
  Future<Uint8List> readBytes(TransactionAttachment attachment) async {
    final path = attachment.storagePath;
    final uid = _uid;
    if (LocalFileCache.isDevicePath(path)) {
      try {
        return await LocalFileCache.read(path);
      } catch (_) {
        // The upload may have finished since this metadata was read; its
        // bytes then moved to the cloud copy's cache key.
        if (uid != null) {
          final moved =
              '${LocalFileCache.pathPrefix}'
              '${_cacheKeyFor(cloudPathFor(uid, attachment))}';
          if (await LocalFileCache.contains(moved)) {
            return LocalFileCache.read(moved);
          }
        }
        throw const AttachmentUnavailableException(offline: false);
      }
    }
    final cacheKey = _cacheKeyFor(path);
    try {
      return await LocalFileCache.read('${LocalFileCache.pathPrefix}$cacheKey');
    } on StateError {
      // Not downloaded to this device yet.
    }
    if (uid == null) throw const AttachmentUnavailableException(offline: false);
    final Uint8List bytes;
    try {
      bytes = await _remoteFiles.get(
        path,
        maxBytes: TransactionAttachment.maxUploadBytes,
      );
    } catch (error) {
      throw AttachmentUnavailableException(
        offline: isTransientFileError(error),
      );
    }
    await LocalFileCache.write(cacheKey, bytes);
    return bytes;
  }

  /// The attachments of [transactionId]: the cloud's (signed in; from the
  /// device cache when offline) plus those waiting on this device.
  Future<List<TransactionAttachment>> listForTransaction(
    String transactionId,
  ) async {
    final userId = await _userContext.resolveUserId();
    final local = await _localRows(userId, transactionId);
    final uid = _uid;
    if (uid == null) return local;
    List<TransactionAttachment>? remote;
    try {
      final query = _remote(
        uid,
      ).where('linked_entity_id', isEqualTo: transactionId);
      final snapshot = await query.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () => query.get(const GetOptions(source: Source.cache)),
      );
      remote = [for (final doc in snapshot.docs) _fromRow(doc.data())];
    } catch (error) {
      if (kDebugMode) debugPrint('[aiko-files] attachment list failed: $error');
    }
    return _merge(local, remote);
  }

  /// [listForTransaction] that updates as attachments are saved, uploaded or
  /// deleted.
  Stream<List<TransactionAttachment>> watchForTransaction(
    String transactionId,
  ) {
    late final StreamController<List<TransactionAttachment>> controller;
    StreamSubscription<void>? localChanges;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? remoteChanges;
    List<TransactionAttachment>? remote;
    var latest = 0;

    Future<void> emit() async {
      final ticket = ++latest;
      try {
        final local = await _localRows(
          await _userContext.resolveUserId(),
          transactionId,
        );
        if (ticket == latest && !controller.isClosed) {
          controller.add(_merge(local, remote));
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<List<TransactionAttachment>>(
      onListen: () {
        localChanges = _localChanges.stream.listen((_) => emit());
        final uid = _uid;
        if (uid != null) {
          remoteChanges = _remote(uid)
              .where('linked_entity_id', isEqualTo: transactionId)
              .snapshots()
              .listen(
                (snapshot) {
                  remote = [
                    for (final doc in snapshot.docs) _fromRow(doc.data()),
                  ];
                  emit();
                },
                onError: (Object error) {
                  if (kDebugMode) {
                    debugPrint('[aiko-files] attachment listener: $error');
                  }
                },
              );
        }
        emit();
      },
      onCancel: () async {
        await localChanges?.cancel();
        await remoteChanges?.cancel();
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }

  Future<List<TransactionAttachment>> exportableForTransaction(
    String transactionId,
  ) async {
    final attachments = await listForTransaction(transactionId);
    return attachments.where((item) => item.isExportable).toList();
  }

  /// After sign-in: hands every guest attachment on this device to [userId]
  /// and queues their uploads. Returns how many were claimed; never throws.
  Future<int> claimGuestAttachments(String userId) async {
    if (userId.isEmpty ||
        userId.startsWith(OfflineUserContext.localUserIdPrefix)) {
      return 0;
    }
    try {
      final db = await _db();
      var claimed = 0;
      await db.transaction((txn) async {
        final rows = await txn.query(
          'attachments',
          columns: const ['data'],
          where: 'owner_id LIKE ?',
          whereArgs: ['${OfflineUserContext.localUserIdPrefix}%'],
        );
        for (final row in rows) {
          final attachment = _decode(row['data']! as String);
          if (attachment == null) continue;
          final owned = attachment.copyWith(userId: userId);
          await _putRow(txn, owned);
          if (LocalFileCache.isDevicePath(owned.storagePath)) {
            await _queue.enqueue(_uploadJob(userId, owned.id), txn: txn);
          }
        }
        claimed = rows.length;
      });
      if (claimed > 0) {
        _localChanges.add(null);
        _queue.notifyChanged();
      }
      return claimed;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-files] attachment claim failed: $error');
      }
      return 0;
    }
  }

  /// Uploads one waiting attachment ([uploadKind] job).
  Future<void> _upload(FileJob job, FileJobRun run) async {
    final id = job.data['attachment_id'] as String;
    final db = await _db();
    final waiting = await _row(db, id);
    if (waiting == null || !LocalFileCache.isDevicePath(waiting.storagePath)) {
      return; // Deleted or already uploaded.
    }
    final Uint8List bytes;
    try {
      bytes = await LocalFileCache.read(waiting.storagePath);
    } catch (error) {
      // The bytes are gone from this device, so the attachment can never be
      // opened or uploaded: drop the broken entry.
      if (kDebugMode) debugPrint('[aiko-files] attachment $id lost: $error');
      await db.delete('attachments', where: 'id = ?', whereArgs: [id]);
      _localChanges.add(null);
      return;
    }
    final cloudPath = cloudPathFor(job.ownerId, waiting);
    await _remoteFiles.put(cloudPath, bytes, contentType: waiting.mimeType);
    final uploaded = waiting.copyWith(
      userId: job.ownerId,
      storagePath: cloudPath,
    );
    // Deleted while uploading: the delete queued removing this file too.
    final current = await _row(db, id);
    if (current == null || current.storagePath != waiting.storagePath) return;
    // No await between the check and handing the write to the SDK, so a
    // delete that comes later also reaches the SDK later.
    await OfflineStore.acceptWrite(
      _remote(job.ownerId).doc(id).set(_toRow(uploaded)),
    );
    await db.transaction((txn) async {
      final latest = await _row(txn, id);
      if (latest == null || latest.storagePath != waiting.storagePath) return;
      // Firestore now holds the metadata; keep the bytes for offline viewing.
      await txn.delete('attachments', where: 'id = ?', whereArgs: [id]);
      final cacheKey = _cacheKeyFor(cloudPath);
      if (waiting.storagePath.startsWith(LocalFileCache.pathPrefix)) {
        await LocalFileCache.move(waiting.storagePath, cacheKey, txn: txn);
      } else {
        await LocalFileCache.write(cacheKey, bytes, txn: txn);
      }
    });
    _localChanges.add(null);
  }

  static FileJob _uploadJob(String ownerId, String attachmentId) => FileJob(
    id: uploadJobId(attachmentId),
    ownerId: ownerId,
    kind: uploadKind,
    data: {'attachment_id': attachmentId},
  );

  Future<List<TransactionAttachment>> _localRows(
    String ownerId,
    String transactionId,
  ) async {
    final db = await _db();
    final rows = await db.query(
      'attachments',
      columns: const ['data'],
      where: 'owner_id = ? AND transaction_id = ?',
      whereArgs: [ownerId, transactionId],
      orderBy: 'created_at, id',
    );
    return [for (final row in rows) ?_decode(row['data']! as String)];
  }

  static Future<TransactionAttachment?> _row(
    DatabaseExecutor db,
    String id,
  ) async {
    final rows = await db.query(
      'attachments',
      columns: const ['data'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _decode(rows.single['data']! as String);
  }

  static Future<void> _putRow(
    DatabaseExecutor txn,
    TransactionAttachment attachment, {
    ConflictAlgorithm conflict = ConflictAlgorithm.replace,
  }) => txn.insert('attachments', {
    'id': attachment.id,
    'owner_id': attachment.userId,
    'transaction_id': attachment.transactionId,
    'data': jsonEncode(_toRow(attachment)),
    'created_at': attachment.createdAt.toUtc().toIso8601String(),
  }, conflictAlgorithm: conflict);

  /// The cloud's attachments plus the ones waiting on this device; without
  /// the cloud's ([remote] null: signed out or unreadable), the device's.
  static List<TransactionAttachment> _merge(
    List<TransactionAttachment> local,
    List<TransactionAttachment>? remote,
  ) {
    if (remote == null) return local;
    final byId = {for (final attachment in remote) attachment.id: attachment};
    for (final attachment in local) {
      if (LocalFileCache.isDevicePath(attachment.storagePath)) {
        byId.putIfAbsent(attachment.id, () => attachment);
      }
    }
    return byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Moves metadata the previous app version kept as one JSON file per
  /// transaction in the byte cache into the `attachments` table, and queues
  /// the uploads that never ran. Signed-in rows already uploaded are left to
  /// Firestore. Runs once per database; never throws.
  Future<void> _importLegacy(Database db) async {
    const prefix = '${LocalFileCache.pathPrefix}attachment-metadata/';
    var queued = false;
    try {
      await db.transaction((txn) async {
        final files = await txn.query(
          'files',
          where: 'path LIKE ?',
          whereArgs: ['$prefix%'],
        );
        for (final file in files) {
          final path = file['path']! as String;
          final key = path.substring(prefix.length);
          final slash = key.lastIndexOf('/');
          final ownerId = slash > 0 ? key.substring(0, slash) : '';
          final signedInOwner = !ownerId.startsWith(
            OfflineUserContext.localUserIdPrefix,
          );
          List<Object?> rows;
          try {
            rows = jsonDecode(utf8.decode(file['bytes']! as List<int>)) as List;
          } catch (_) {
            rows = const [];
          }
          for (final row in rows) {
            final TransactionAttachment attachment;
            try {
              attachment = _fromRow({
                ...(row! as Map).cast<String, dynamic>(),
                'user_id': ownerId,
              });
            } catch (_) {
              continue;
            }
            final onDevice = LocalFileCache.isDevicePath(
              attachment.storagePath,
            );
            if (ownerId.isEmpty || (signedInOwner && !onDevice)) continue;
            await _putRow(txn, attachment, conflict: ConflictAlgorithm.ignore);
            if (signedInOwner) {
              await _queue.enqueue(
                _uploadJob(ownerId, attachment.id),
                txn: txn,
              );
              queued = true;
            }
          }
          await txn.delete('files', where: 'path = ?', whereArgs: [path]);
        }
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[aiko-files] attachment metadata import failed: $error');
      }
    }
    if (queued) _queue.notifyChanged();
  }

  static TransactionAttachment? _decode(String data) {
    try {
      return _fromRow((jsonDecode(data) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  static TransactionAttachment _fromRow(Map<String, dynamic> row) {
    final exportPolicy = AttachmentExportPolicy.values.firstWhere(
      (item) => item.name == (row['export_policy'] as String? ?? 'include'),
      orElse: () => AttachmentExportPolicy.include,
    );

    return TransactionAttachment(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      transactionId: row['linked_entity_id'] as String,
      fileName: row['file_name'] as String,
      storagePath: row['storage_path'] as String,
      mimeType: row['content_type'] as String,
      sizeBytes: int.parse('${row['size_bytes'] ?? 0}'),
      createdAt: DateTime.parse(row['created_at'] as String),
      isSensitive: row['is_sensitive'] as bool? ?? false,
      exportPolicy: exportPolicy,
    );
  }

  static Map<String, dynamic> _toRow(TransactionAttachment attachment) {
    return {
      'created_at': attachment.createdAt.toUtc().toIso8601String(),
      'id': attachment.id,
      'user_id': attachment.userId,
      'storage_bucket': 'receipts',
      'storage_path': attachment.storagePath,
      'file_name': attachment.fileName,
      'content_type': attachment.mimeType,
      'size_bytes': attachment.sizeBytes,
      'linked_entity_type': 'transaction',
      'linked_entity_id': attachment.transactionId,
      'is_sensitive': attachment.isSensitive,
      'export_policy': attachment.exportPolicy.name,
    };
  }
}
