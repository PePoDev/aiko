import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:another_telephony/telephony.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/money/money.dart';
import '../../core/storage/secure_storage_service.dart';
import '../transactions/domain/transaction.dart';
import 'bank_message_parser.dart';

/// A captured SMS or notification waiting to be turned into a transaction.
class CapturedMessage {
  CapturedMessage({
    required this.id,
    required this.source,
    required this.sender,
    required this.body,
    required this.receivedAt,
  });

  final String id;
  final String source; // 'sms' | 'notification'
  final String sender; // SMS address or notifying package name
  final String body;
  final DateTime receivedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'sender': sender,
    'body': body,
    'received_at': receivedAt.toIso8601String(),
  };

  factory CapturedMessage.fromJson(Map<String, dynamic> json) => CapturedMessage(
    id: json['id'] as String,
    source: json['source'] as String? ?? 'sms',
    sender: json['sender'] as String? ?? '',
    body: json['body'] as String? ?? '',
    receivedAt:
        DateTime.tryParse(json['received_at'] as String? ?? '') ??
        DateTime.now(),
  );
}

String _newCaptureId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

/// Durable capture queue: one JSON file per message in a dedicated dir.
///
/// ponytail: one-file-per-message instead of a shared log so the SMS
/// background isolate and the foreground notification stream never race on
/// the same file. The processor drains and deletes them. Upgrade path: a
/// real table if we ever need querying/dedupe beyond "process then delete".
class CapturedMessageInbox {
  const CapturedMessageInbox();

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/capture_inbox');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> add(CapturedMessage message) async {
    final dir = await _dir();
    await File(
      '${dir.path}/${message.id}.json',
    ).writeAsString(jsonEncode(message.toJson()), flush: true);
  }

  Future<List<CapturedMessage>> drain() async {
    final dir = await _dir();
    final files =
        (await dir.list().toList()).whereType<File>().where(
          (f) => f.path.endsWith('.json'),
        ).toList()..sort((a, b) => a.path.compareTo(b.path));
    final out = <CapturedMessage>[];
    for (final file in files) {
      try {
        out.add(
          CapturedMessage.fromJson(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        await file.delete(); // corrupt entry — drop it
      }
    }
    return out;
  }

  Future<void> remove(String id) async {
    final dir = await _dir();
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) await file.delete();
  }
}

/// Entry point for SMS received while the app is backgrounded/killed. Must be
/// top-level and `vm:entry-point` — Android spawns a fresh isolate for it.
@pragma('vm:entry-point')
Future<void> captureSmsBackgroundHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await const CapturedMessageInbox().add(
    CapturedMessage(
      id: _newCaptureId(),
      source: 'sms',
      sender: message.address ?? '',
      body: message.body ?? '',
      receivedAt: DateTime.now(),
    ),
  );
}

/// Owns the OS permission grants and the live listeners that drop messages
/// into the inbox. Android-only; the plugins no-op elsewhere.
class TransactionCaptureService {
  TransactionCaptureService();

  final _telephony = Telephony.instance;
  final _inbox = const CapturedMessageInbox();
  StreamSubscription<ServiceNotificationEvent>? _notifSub;

  Future<bool> notificationsGranted() =>
      NotificationListenerService.isPermissionGranted();

  /// Opens the system "notification access" screen for the user to grant.
  Future<bool> requestNotifications() =>
      NotificationListenerService.requestPermission();

  Future<bool> requestSms() async =>
      await _telephony.requestPhoneAndSmsPermissions ?? false;

  Future<void> start() async {
    _telephony.listenIncomingSms(
      onNewMessage: (message) => _inbox.add(
        CapturedMessage(
          id: _newCaptureId(),
          source: 'sms',
          sender: message.address ?? '',
          body: message.body ?? '',
          receivedAt: DateTime.now(),
        ),
      ),
      onBackgroundMessage: captureSmsBackgroundHandler,
      listenInBackground: true,
    );

    // ponytail: the notification stream only fires while the Flutter engine is
    // alive (foreground or backgrounded-but-not-killed). That covers the common
    // case; the inbox is drained on resume. Upgrade path: a foreground service
    // if you need notifications captured after the OS kills the engine.
    await _notifSub?.cancel();
    _notifSub = NotificationListenerService.notificationsStream.listen((event) {
      if (event.hasRemoved == true) return;
      final body = '${event.title ?? ''} ${event.content ?? ''}'.trim();
      if (body.isEmpty) return;
      _inbox.add(
        CapturedMessage(
          id: _newCaptureId(),
          source: 'notification',
          sender: event.packageName ?? '',
          body: body,
          receivedAt: DateTime.now(),
        ),
      );
    });
  }

  Future<void> stop() async {
    await _notifSub?.cancel();
    _notifSub = null;
  }
}

/// Drains the inbox, parses each message, and auto-creates transactions on the
/// user's chosen capture account. Runs on app start and on resume.
class CapturedMessageProcessor {
  CapturedMessageProcessor(this._ref);

  final Ref _ref;
  final _inbox = const CapturedMessageInbox();
  final _parser = const BankMessageParser();
  final _uuid = const Uuid();

  Future<int> processInbox() async {
    final settings = await TransactionCaptureSettings.load();
    if (!settings.enabled || settings.accountId == null) return 0;

    final messages = await _inbox.drain();
    if (messages.isEmpty) return 0;

    final accounts = await _ref.read(accountsProvider.future);
    final account = accounts
        .where((a) => a.id == settings.accountId)
        .firstOrNull;
    if (account == null) return 0; // capture account was deleted

    final currency =
        _ref.read(profileProvider).value?.baseCurrency ?? account.currency;
    final notifier = _ref.read(transactionsProvider.notifier);

    var created = 0;
    for (final message in messages) {
      final parsed = _parser.parse(message.body);
      if (parsed != null) {
        await notifier.addTransaction(
          FinanceTransaction(
            id: _uuid.v4(),
            userId: '', // repository stamps the signed-in user
            accountId: account.id,
            type: parsed.type,
            amount: Money(
              amount: Decimal.parse(parsed.amount),
              currency: currency,
            ),
            date: message.receivedAt,
            merchant: parsed.merchant ?? message.sender,
            note: 'Auto-captured from ${message.source}',
            tags: const ['captured'],
          ),
        );
        created++;
      }
      // Drop whether parsed or not, so the queue never re-scans the same text.
      await _inbox.remove(message.id);
    }
    return created;
  }
}

/// Persisted on/off switch + the account auto-captured transactions land on.
class TransactionCaptureSettings {
  const TransactionCaptureSettings({required this.enabled, this.accountId});

  final bool enabled;
  final String? accountId;

  static const _key = 'transaction_capture_settings';

  TransactionCaptureSettings copyWith({bool? enabled, String? accountId}) =>
      TransactionCaptureSettings(
        enabled: enabled ?? this.enabled,
        accountId: accountId ?? this.accountId,
      );

  static Future<TransactionCaptureSettings> load([
    SecureStorageService? storage,
  ]) async {
    final store = storage ?? FlutterSecureStorageService();
    try {
      final raw = await store.read(_key);
      if (raw == null || raw.isEmpty) {
        return const TransactionCaptureSettings(enabled: false);
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TransactionCaptureSettings(
        enabled: json['enabled'] as bool? ?? false,
        accountId: json['account_id'] as String?,
      );
    } catch (_) {
      return const TransactionCaptureSettings(enabled: false);
    }
  }

  Future<void> save([SecureStorageService? storage]) async {
    final store = storage ?? FlutterSecureStorageService();
    await store.write(
      _key,
      jsonEncode({'enabled': enabled, 'account_id': accountId}),
    );
  }
}

final transactionCaptureServiceProvider = Provider<TransactionCaptureService>(
  (_) => TransactionCaptureService(),
);

final transactionCaptureProcessorProvider = Provider<CapturedMessageProcessor>(
  (ref) => CapturedMessageProcessor(ref),
);
