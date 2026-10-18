import 'dart:async';

import 'package:flutter/foundation.dart';

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

  /// Takes [ownerId]'s waiting jobs off the queue and lets an upload that is
  /// running finish, so none completes after the server deleted the account
  /// (it would put the file, and its record, back). Returns the jobs taken,
  /// for [release] should the account stay; null when the running upload
  /// didn't finish within [timeout] (the jobs are back on the queue then).
  Future<List<FileJob>?> hold(
    String ownerId, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final List<FileJob> held;
    try {
      held = await queue.pending(ownerId: ownerId);
      for (final job in held) {
        await queue.remove(job.id);
      }
    } catch (error) {
      // An unreadable queue runs no uploads either.
      debugPrint('[auth] upload queue unreadable: $error');
      return const [];
    }
    var settled = true;
    // A pass that is running ends after the jobs it started with.
    await queue.process().timeout(timeout, onTimeout: () => settled = false);
    if (settled) return held;
    await release(held);
    return null;
  }

  /// Puts [jobs] taken by [hold] back on the queue.
  Future<void> release(List<FileJob> jobs) async {
    for (final job in jobs) {
      try {
        await queue.enqueue(job);
      } catch (error) {
        debugPrint('[auth] upload ${job.id} not queued again: $error');
      }
    }
  }

  /// Deletes every job of [ownerId] (their account is gone).
  Future<void> drop(String ownerId) async {
    try {
      for (final job in await queue.pending(ownerId: ownerId)) {
        await queue.remove(job.id);
      }
    } catch (error) {
      debugPrint('[auth] upload queue unreadable: $error');
    }
  }
}
