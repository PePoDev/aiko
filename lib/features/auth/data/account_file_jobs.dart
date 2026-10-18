import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../app/file_uploads.dart';
import '../../../core/storage/file_sync_queue.dart';

/// One account's jobs in the file upload queue ([FileSyncQueue]: attachment
/// and profile photo uploads, and Storage deletes), around logging out and
/// deleting the account. The queue runs them only while their owner is
/// signed in on this device.
class AccountFileJobs {
  AccountFileJobs(this.queue);

  final FileSyncQueue queue;

  /// Whether [ownerId]'s files still wait to upload after they were given
  /// [timeout] to.
  Future<bool> waiting(String ownerId, {required Duration timeout}) async {
    try {
      if (await queue.pendingCount(ownerId) == 0) return false;
      await queue.process().timeout(timeout, onTimeout: () {});
      return await queue.pendingCount(ownerId) > 0;
    } catch (error) {
      debugPrint('[auth] upload queue unreadable: $error');
      return false;
    }
  }

  /// Stops the queue before the account is deleted, so that no upload
  /// completes after the server deleted it (it would put the file, and its
  /// record, back): no job starts until [release], and the one running now
  /// finishes first. The jobs stay queued. False when the running one didn't
  /// finish within [timeout]; the queue runs again then.
  Future<bool> hold({Duration timeout = const Duration(seconds: 15)}) async {
    var settled = true;
    try {
      await queue.suspend().timeout(timeout, onTimeout: () => settled = false);
    } catch (error) {
      // The pass ended with an error: nothing runs any more.
      debugPrint('[auth] upload queue pass failed: $error');
    }
    if (!settled) release();
    return settled;
  }

  /// Lets the queue run again after [hold].
  void release() => queue.resume();

  /// After [ownerId]'s account was deleted: forgets their waiting jobs
  /// (those queued meanwhile too), the attachments kept on this device for
  /// them and the cached copies of their files ([forgetFilesOf]).
  Future<void> forget(String ownerId) async {
    try {
      await forgetFilesOf(ownerId, queue: queue);
    } catch (error) {
      debugPrint('[auth] files of the deleted account not forgotten: $error');
    }
  }
}
