import 'package:flutter/foundation.dart';
import '../../l10n/l10n.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show DartPluginRegistrant;

import 'package:another_telephony/telephony.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/money/money.dart';
import '../../core/storage/secure_storage_service.dart';
import '../transactions/data/transaction_rule_store.dart';
import '../transactions/domain/transaction.dart';
import '../transactions/domain/transaction_rule.dart';
import 'bank_message_parser.dart';

/// A captured SMS or notification waiting to be turned into a transaction.
class CapturedMessage {
  CapturedMessage({
    required this.id,
    required this.source,
    required this.sender,
    required this.body,
    required this.receivedAt,
    this.notificationKey,
  });

  final String id;
  final String source; // 'sms' | 'notification'
  final String sender; // SMS address or notifying package name
  final String body;

  /// When the money moved, as near as the message tells: an SMS's sending
  /// time, or when a notification was captured.
  final DateTime receivedAt;

  /// The posted notification's key (the same while an app updates one
  /// notification); null for an SMS.
  final String? notificationKey;

  /// The channel it came through: all SMS share one; each app posting
  /// notifications is its own.
  String get origin => source == _smsSource ? _smsSource : '$source:$sender';

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'sender': sender,
    'body': body,
    'received_at': receivedAt.toIso8601String(),
    if (notificationKey != null) 'notification_key': notificationKey,
  };

  factory CapturedMessage.fromJson(Map<String, dynamic> json) =>
      CapturedMessage(
        id: json['id'] as String,
        source: json['source'] as String? ?? 'sms',
        sender: json['sender'] as String? ?? '',
        body: json['body'] as String? ?? '',
        receivedAt:
            DateTime.tryParse(json['received_at'] as String? ?? '') ??
            DateTime.now(),
        notificationKey: json['notification_key'] as String?,
      );
}

const _smsSource = 'sms';
const _notificationSource = 'notification';

/// Aiko's own Android package (`applicationId` in
/// android/app/build.gradle.kts). Its reminder notifications quote amounts
/// ("฿5,000.00 · รายจ่าย") and must never come back as captured transactions.
const _ownPackage = 'dev.pepo.aiko';

const _captureParser = BankMessageParser();

String _newCaptureId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

/// The inbox entry for an incoming SMS, or null when the text isn't a money
/// movement, so personal texts are never written to disk. [timestamp] is the
/// SMS's service centre timestamp in milliseconds ([SmsMessage.date]).
CapturedMessage? capturedSms({String? address, String? body, int? timestamp}) {
  final text = body?.trim() ?? '';
  if (_captureParser.parse(text) == null) return null;
  return CapturedMessage(
    id: _newCaptureId(),
    source: _smsSource,
    sender: address ?? '',
    body: text,
    receivedAt: smsSentAt(timestamp, DateTime.now()),
  );
}

/// The oldest SMS timestamp taken at face value: service centres keep an SMS
/// they can't deliver for about a week at most.
const _maxSmsDelay = Duration(days: 7);

/// When an SMS was sent, from its service centre [timestamp] (milliseconds
/// since the epoch), so one the carrier delivers late keeps its own date and
/// still matches the bank app's notification of the same payment. No
/// timestamp, or one no delivery delay explains (later than [now], or more
/// than a week old: a wrong service centre clock), counts as [now].
@visibleForTesting
DateTime smsSentAt(int? timestamp, DateTime now) {
  if (timestamp == null) return now;
  final sent = DateTime.fromMillisecondsSinceEpoch(timestamp);
  if (sent.isAfter(now) || now.difference(sent) > _maxSmsDelay) return now;
  return sent;
}

/// The inbox entry for a posted notification, or null when it isn't one to
/// capture: one of Aiko's own, or text that isn't a money movement. [key] is
/// the notification's key (the same while its app updates it).
CapturedMessage? capturedNotification({
  String? packageName,
  String? title,
  String? content,
  String? key,
}) {
  if (packageName == _ownPackage) return null;
  final text = '${title ?? ''} ${content ?? ''}'.trim();
  if (_captureParser.parse(text) == null) return null;
  return CapturedMessage(
    id: _newCaptureId(),
    source: _notificationSource,
    sender: packageName ?? '',
    body: text,
    receivedAt: DateTime.now(),
    notificationKey: key,
  );
}

/// The inbox entry for an [event] of Aiko's notification listener
/// (CaptureNotificationListener in android/app: a map of the posting
/// package, the notification's key, title and text), or null when it isn't
/// one to capture.
CapturedMessage? capturedNotificationEvent(Object? event) {
  if (event is! Map) return null;
  String? text(String name) => switch (event[name]) {
    final String value => value,
    _ => null,
  };
  return capturedNotification(
    packageName: text('packageName'),
    title: text('title'),
    content: text('content'),
    key: text('key'),
  );
}

/// UUID namespace of transactions booked from captured messages.
const _captureNamespace = '6f1c2b7e-3d4a-4e5f-9a8b-0c1d2e3f4a5b';

/// The id of the transaction booked from [message], derived from its inbox
/// id. A message processed again because the app stopped after saving its
/// transaction but before removing it from the inbox maps to the same
/// transaction, which is already saved, so it isn't booked twice.
String capturedTransactionId(CapturedMessage message) =>
    const Uuid().v5(_captureNamespace, 'capture/${message.id}');

/// Durable capture queue: one JSON file per message in a dedicated dir.
///
/// ponytail: one-file-per-message instead of a shared log so the SMS
/// background isolate and the foreground notification stream never race on
/// the same file. The processor drains and deletes them. Upgrade path: a
/// real table if we ever need querying beyond "process then delete".
class CapturedMessageInbox {
  const CapturedMessageInbox({this.directory});

  /// The queue folder; defaults to `capture_inbox` in the app support
  /// directory. Tests pass a temporary one.
  final Directory? directory;

  Future<Directory> _dir() async {
    final dir =
        directory ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}/capture_inbox',
        );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> add(CapturedMessage message) async {
    final dir = await _dir();
    // Written under a temporary name, then renamed into place: a drain
    // running at the same time (the background isolate shares this folder)
    // never reads, and drops, half a message.
    final temp = File('${dir.path}/${message.id}.tmp');
    await temp.writeAsString(jsonEncode(message.toJson()), flush: true);
    await temp.rename('${dir.path}/${message.id}.json');
  }

  Future<List<CapturedMessage>> drain() async {
    final dir = await _dir();
    final files = (await dir.list().toList()).whereType<File>().toList();
    final queued = files.where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final out = <CapturedMessage>[];
    for (final file in queued) {
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
    for (final file in files.where((f) => f.path.endsWith('.tmp'))) {
      try {
        // Left behind by a write that never finished.
        final age = DateTime.now().difference((await file.stat()).modified);
        if (age > const Duration(hours: 1)) await file.delete();
      } on FileSystemException catch (_) {
        // Renamed or deleted meanwhile.
      }
    }
    return out;
  }

  Future<void> remove(String id) async {
    final dir = await _dir();
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) await file.delete();
  }

  /// Drops every queued message.
  Future<void> clear() async {
    final dir = await _dir();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      try {
        await entity.delete();
      } on FileSystemException catch (_) {
        // Already gone.
      }
    }
  }
}

/// How far apart two captures of the same money movement can arrive (an SMS
/// and the notification for it, or a notification its app posts again).
const captureDuplicateWindow = Duration(minutes: 5);

/// How far apart one app's notifications with the same text, posted as two
/// notifications (a group summary repeating one, or an alert posted twice),
/// still count as one movement. Further apart they are two payments that
/// read alike; the same notification updated stays one for the whole
/// [captureDuplicateWindow].
const captureRepostWindow = Duration(minutes: 1);

/// What the processor remembers about a message it booked or matched to an
/// earlier one: enough to spot the same money movement arriving again.
class CaptureRecord {
  const CaptureRecord({
    required this.id,
    required this.origin,
    required this.textHash,
    required this.type,
    required this.amount,
    required this.at,
    this.keyHash,
    this.duplicateOf,
  });

  factory CaptureRecord.of(CapturedMessage message, FinanceTransaction draft) =>
      CaptureRecord(
        id: message.id,
        origin: message.origin,
        textHash: _textHash(message.body),
        type: draft.type.name,
        amount: draft.amount.amount.toString(),
        at: message.receivedAt,
        keyHash: switch (message.notificationKey) {
          final String key => _textHash(key),
          null => null,
        },
      );

  factory CaptureRecord.fromJson(Map<String, dynamic> json) => CaptureRecord(
    id: json['id'] as String,
    origin: json['origin'] as String,
    textHash: json['text'] as String,
    type: json['type'] as String,
    amount: json['amount'] as String,
    at: DateTime.parse(json['at'] as String),
    keyHash: json['key'] as String?,
    duplicateOf: json['duplicate_of'] as String?,
  );

  /// The [CapturedMessage.id] it was made from.
  final String id;
  final String origin;

  /// A hash of the message text: enough to compare, without keeping it.
  final String textHash;
  final String type;
  final String amount;
  final DateTime at;

  /// A hash of the notification's key; null for an SMS (or a record kept
  /// before keys were).
  final String? keyHash;

  /// The booked message this one repeated; null when it was booked itself.
  final String? duplicateOf;

  CaptureRecord asDuplicateOf(String original) => CaptureRecord(
    id: id,
    origin: origin,
    textHash: textHash,
    type: type,
    amount: amount,
    at: at,
    keyHash: keyHash,
    duplicateOf: original,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'origin': origin,
    'text': textHash,
    'type': type,
    'amount': amount,
    'at': at.toIso8601String(),
    if (keyHash != null) 'key': keyHash,
    if (duplicateOf != null) 'duplicate_of': duplicateOf,
  };
}

/// FNV-1a of the text with case and spacing evened out.
String _textHash(String text) {
  final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  var hash = 0x811c9dc5;
  for (final unit in normalized.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16);
}

/// The most recent [CaptureRecord]s, oldest first.
class CaptureLedger {
  CaptureLedger([Iterable<CaptureRecord> records = const []])
    : _records = [...records];

  factory CaptureLedger.fromJson(Object? json) => CaptureLedger([
    if (json is List)
      for (final item in json)
        CaptureRecord.fromJson(item as Map<String, dynamic>),
  ]);

  /// Plenty for [captureDuplicateWindow], and for a message whose removal
  /// from the inbox was lost to still be found when the app next starts.
  static const maxRecords = 200;

  final List<CaptureRecord> _records;

  List<CaptureRecord> get records => List.unmodifiable(_records);

  bool contains(String messageId) => _records.any((r) => r.id == messageId);

  void add(CaptureRecord record) {
    _records
      ..removeWhere((r) => r.id == record.id)
      ..add(record);
    if (_records.length > maxRecords) {
      _records.removeRange(0, _records.length - maxRecords);
    }
  }

  /// The id of the booked message [next] repeats, or null when it is new.
  String? originalOf(CaptureRecord next) {
    bool near(CaptureRecord r) =>
        r.at.difference(next.at).abs() <= captureDuplicateWindow;

    // The same notification posted again: an update of it (the same key),
    // or the same text posted as another notification moments later. Two SMS
    // with the same text are two messages, so SMS never match here.
    if (next.origin != _smsSource) {
      for (final r in _records) {
        if (r.id == next.id ||
            r.origin != next.origin ||
            r.textHash != next.textHash) {
          continue;
        }
        final sameNotification = r.keyHash != null && r.keyHash == next.keyHash;
        final repost = sameNotification
            ? near(r)
            : r.at.difference(next.at).abs() <= captureRepostWindow;
        if (repost) return r.duplicateOf ?? r.id;
      }
    }
    // The same movement reported through another channel: the bank's SMS and
    // the SMS app's notification of it, or the bank app's own notification.
    // A booked message stands in for one message per channel, so two equal
    // purchases reported both ways stay two.
    for (final r in _records) {
      if (r.duplicateOf != null || r.origin == next.origin) continue;
      if (r.type != next.type || r.amount != next.amount || !near(r)) continue;
      final taken = _records.any(
        (d) => d.duplicateOf == r.id && d.origin == next.origin,
      );
      if (!taken) return r.id;
    }
    return null;
  }

  List<Map<String, dynamic>> toJson() => [
    for (final record in _records) record.toJson(),
  ];
}

/// Keeps the [CaptureLedger] in the app support directory.
class CaptureLedgerStore {
  const CaptureLedgerStore({this.file});

  /// Defaults to `capture_ledger.json` in the app support directory.
  final File? file;

  Future<File> _file() async =>
      file ??
      File(
        '${(await getApplicationSupportDirectory()).path}/'
        'capture_ledger.json',
      );

  Future<CaptureLedger> load() async {
    try {
      final source = await _file();
      if (!await source.exists()) return CaptureLedger();
      return CaptureLedger.fromJson(jsonDecode(await source.readAsString()));
    } catch (error) {
      // Start a new one: it only spots repeats from another channel, and the
      // transaction ids still keep a message from being booked twice.
      debugPrint('Capture ledger reset: $error');
      return CaptureLedger();
    }
  }

  Future<void> save(CaptureLedger ledger) async {
    final target = await _file();
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(ledger.toJson()), flush: true);
    await temp.rename(target.path);
  }
}

/// Entry point for SMS received while the app is in the background, the
/// screen is locked, or the app is not running. Android starts a separate
/// isolate for it, so it must stay top-level and `vm:entry-point`. It only
/// queues the message, on the device with no network needed; the app books
/// it on its next start or resume.
@pragma('vm:entry-point')
Future<void> captureSmsBackgroundHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Plugins with a Dart-side implementation (path_provider) register here.
  DartPluginRegistrant.ensureInitialized();
  await queueBackgroundSms(
    address: message.address,
    body: message.body,
    timestamp: message.date,
  );
}

/// Queues an SMS the background isolate received; true when it was queued.
///
/// Only money movements are kept, and nothing while auto-capture is off.
/// [TransactionCaptureService.stop] switches the SMS receiver off, but one
/// that was already on its way may still arrive, so the switch is checked
/// here too. Settings that can't be read queue the message anyway; the
/// processor decides once they can.
@visibleForTesting
Future<bool> queueBackgroundSms({
  String? address,
  String? body,
  int? timestamp,
  CapturedMessageInbox inbox = const CapturedMessageInbox(),
  SecureStorageService? storage,
}) async {
  final captured = capturedSms(
    address: address,
    body: body,
    timestamp: timestamp,
  );
  if (captured == null) return false;
  final settings = await TransactionCaptureSettings.tryLoad(storage);
  if (settings != null && !settings.enabled) return false;
  await inbox.add(captured);
  return true;
}

/// Aiko's own bridge to its Android capture components (CaptureBridge in
/// android/app): notification access, the SMS receiver switch, and the
/// notifications CaptureNotificationListener passes on, all inside Aiko's
/// process.
const _captureChannel = MethodChannel('dev.pepo.aiko/capture');
const _capturedNotifications = EventChannel(
  'dev.pepo.aiko/capture/notifications',
);

/// Owns the OS permission grants and the live listeners that drop messages
/// into the inbox. Android-only; elsewhere nothing is captured.
class TransactionCaptureService {
  TransactionCaptureService({this.onQueued});

  /// Called when a message captured while the app runs is in the inbox.
  final VoidCallback? onQueued;

  final _telephony = Telephony.instance;
  final _inbox = const CapturedMessageInbox();
  StreamSubscription<Object?>? _notifSub;

  /// Whether SMS reaching the foreground listener are queued; the plugin
  /// keeps the listener until the app stops.
  var _smsOn = false;

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> notificationsGranted() async =>
      _android && await _call('notificationAccessGranted') == true;

  /// Opens the system "notification access" screen for the user to grant;
  /// true when access is on once they come back.
  Future<bool> requestNotifications() async =>
      _android && await _call('requestNotificationAccess') == true;

  Future<bool> requestSms() async {
    if (!_android) return false;
    final granted = await _telephony.requestPhoneAndSmsPermissions ?? false;
    // Capture is on but SMS access came only now: the background handler
    // couldn't be registered without it, so register it now.
    if (granted && _smsOn) _listenSms();
    return granted;
  }

  Future<void> start() async {
    if (!_android) return; // SMS/notification capture is Android-only
    _smsOn = true;
    _listenSms();
    // The receiver only hands SMS on once the handler registered above is
    // stored, so switching it on right away is safe.
    await _call('setSmsReceiverEnabled', true);

    // ponytail: notifications only arrive while the Flutter engine is alive
    // (foreground or backgrounded-but-not-killed). That covers the common
    // case; the inbox is drained on resume. Upgrade path: queue them from
    // CaptureNotificationListener when no engine is listening.
    await _notifSub?.cancel();
    _notifSub = _capturedNotifications.receiveBroadcastStream().listen(
      (event) => _queue(capturedNotificationEvent(event)),
      onError: (Object error) =>
          debugPrint('Notification capture failed: $error'),
    );
  }

  /// Stops queuing captured messages and switches the SMS receiver off, so
  /// no SMS starts Aiko's background handler while capture is off.
  Future<void> stop() async {
    _smsOn = false;
    await _notifSub?.cancel();
    _notifSub = null;
    if (_android) await _call('setSmsReceiverEnabled', false);
  }

  /// Hands SMS to the foreground listener and, while the app is in the
  /// background or not running, to [captureSmsBackgroundHandler]. Without
  /// SMS access the plugin asks for it first and registers nothing if it is
  /// refused.
  void _listenSms() {
    _telephony.listenIncomingSms(
      onNewMessage: (message) {
        if (!_smsOn) return;
        _queue(
          capturedSms(
            address: message.address,
            body: message.body,
            timestamp: message.date,
          ),
        );
      },
      onBackgroundMessage: captureSmsBackgroundHandler,
      listenInBackground: true,
    );
  }

  Future<Object?> _call(String method, [Object? arguments]) async {
    try {
      return await _captureChannel.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint('Capture $method failed: $error');
    } on MissingPluginException catch (_) {
      // Not Aiko's Android app (a test, or another embedding).
    }
    return null;
  }

  Future<void> _queue(CapturedMessage? message) async {
    if (message == null) return;
    try {
      await _inbox.add(message);
    } catch (error) {
      debugPrint('Could not queue captured message: $error');
      return;
    }
    onQueued?.call();
  }
}

/// Drains the inbox, parses each message, and auto-creates transactions on the
/// user's chosen capture account. Runs on app start, on resume, and shortly
/// after a message is captured while the app runs.
class CapturedMessageProcessor {
  CapturedMessageProcessor(
    this._ref, {
    CapturedMessageInbox inbox = const CapturedMessageInbox(),
    CaptureLedgerStore ledger = const CaptureLedgerStore(),
    SecureStorageService? settingsStorage,
  }) : _inbox = inbox,
       _ledger = ledger,
       _settingsStorage = settingsStorage;

  final Ref _ref;
  final CapturedMessageInbox _inbox;
  final CaptureLedgerStore _ledger;

  /// Where [TransactionCaptureSettings] are read; null for the device's.
  final SecureStorageService? _settingsStorage;
  final _parser = const BankMessageParser();
  final _matcher = const TransactionRuleMatcher();

  // Bootstrap, app resume and a fresh capture can all ask at once; a second
  // caller joins the run in flight instead of draining (and booking) the same
  // messages again, and that run then drains once more for anything queued
  // after it started.
  static Future<int>? _inFlight;
  static var _drainAgain = false;

  Future<int> processInbox() {
    final running = _inFlight;
    if (running != null) {
      _drainAgain = true;
      return running;
    }
    return _inFlight = _drainUntilSettled().whenComplete(
      () => _inFlight = null,
    );
  }

  Future<int> _drainUntilSettled() async {
    var created = 0;
    do {
      _drainAgain = false;
      created += await _processInbox();
    } while (_drainAgain);
    return created;
  }

  Future<int> _processInbox() async {
    if (!(!kIsWeb && defaultTargetPlatform == TargetPlatform.android)) return 0;
    final settings = await TransactionCaptureSettings.tryLoad(_settingsStorage);
    if (settings == null) return 0; // unreadable for now; keep the queue
    if (!settings.enabled) {
      // Queued while auto-capture was off (an SMS already on its way when it
      // was switched off): never book these later.
      await _inbox.clear();
      return 0;
    }
    final accountId = settings.accountId;
    if (accountId == null) return 0;

    final messages = await _inbox.drain();
    if (messages.isEmpty) return 0;

    // firebase_sync invalidates the transactions list after every snapshot,
    // this run's own writes included. Listening keeps it alive through that
    // (it rebuilds instead), so the notifier booking below stays usable even
    // on a screen that doesn't show transactions.
    final transactions = _ref.listen(transactionsProvider, (_, _) {});
    try {
      return await _book(messages, accountId);
    } finally {
      transactions.close();
    }
  }

  Future<int> _book(List<CapturedMessage> messages, String accountId) async {
    final accounts = await _ref.read(accountsProvider.future);
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return 0; // capture account was deleted

    // A bank's message states amounts in that account's currency.
    final currency = account.currency;
    final rules = await _ref.read(transactionRulesProvider.future);
    // Saved transaction ids, to recognise a message that was booked before
    // the app stopped but never removed from the inbox.
    final saved = {
      for (final transaction in await _ref.read(transactionsProvider.future))
        transaction.id,
    };
    final notifier = _ref.read(transactionsProvider.notifier);
    final ledger = await _ledger.load();

    final l10n = currentL10n();
    return bookCapturedMessages(
      messages,
      draftFor: (message, transactionId) {
        final parsed = _parser.parse(message.body);
        if (parsed == null) return null;
        // Run the captured draft through the user's rules so it lands
        // categorized/tagged the same way a manual entry would.
        return _matcher.apply(
          FinanceTransaction(
            id: transactionId,
            userId: '', // repository stamps the signed-in user
            accountId: account.id,
            type: parsed.type,
            amount: Money(
              amount: Decimal.parse(parsed.amount),
              currency: currency,
            ),
            date: message.receivedAt,
            merchant: parsed.merchant ?? message.sender,
            note: message.source == _notificationSource
                ? l10n.captureNoteFromNotification
                : l10n.captureNoteFromSms,
            tags: const ['captured'],
          ),
          rules,
        );
      },
      isBooked: saved.contains,
      // One write together with the capture account's balance, so bookings
      // never race each other to set it.
      add: notifier.saveTransactions,
      remove: _inbox.remove,
      ledger: ledger,
      saveLedger: _ledger.save,
    );
  }
}

/// At most this many captured messages are booked in one write; with the
/// capture account's balance that stays within one batch
/// ([OfflineStore.maxBatchWrites]).
const _maxBookedPerWrite = 400;

/// Books the captured [messages] and removes them from the inbox through
/// [remove]; returns how many transactions were created.
///
/// [draftFor] builds the transaction with the id it is given
/// ([capturedTransactionId]). The message's inbox id is its stable key: it
/// is on disk before booking starts, and the transaction is saved under the
/// id derived from it, so the key lands in the same write. A message is
/// booked at most once:
/// - one whose transaction [isBooked] already, or that [ledger] already
///   holds, was handled before the app stopped and is only removed;
/// - one the [ledger] matches to a booked message (the same movement from
///   another channel, or a notification posted again) is recorded as a
///   repeat and removed.
///
/// Messages booked by a run that stopped before recording them in [ledger]
/// are recorded first, so a repeat of one that sorts earlier in the inbox
/// is still recognised.
///
/// Everything new is booked through one [add] (more than
/// [_maxBookedPerWrite] messages take several), so the account balance is
/// written once. When that fails, the messages are booked one per [add]:
/// one that still fails stays in the inbox for the next run (booking it
/// again is safe, see above) and holds back nothing else, unless the draft
/// itself is invalid (an [ArgumentError]), which no retry fixes. A message
/// that doesn't parse ([draftFor] returns null or throws) or would book a
/// zero or negative amount is dropped.
@visibleForTesting
Future<int> bookCapturedMessages(
  List<CapturedMessage> messages, {
  required FinanceTransaction? Function(
    CapturedMessage message,
    String transactionId,
  )
  draftFor,
  required bool Function(String transactionId) isBooked,
  required Future<void> Function(List<FinanceTransaction> drafts) add,
  required Future<void> Function(String id) remove,
  CaptureLedger? ledger,
  Future<void> Function(CaptureLedger ledger)? saveLedger,
}) async {
  final seen = ledger ?? CaptureLedger();
  // Transaction ids this run has written.
  final booked = <String>{};
  bool alreadyBooked(String id) => booked.contains(id) || isBooked(id);

  Future<void> saveSeen() async {
    try {
      await saveLedger?.call(seen);
    } catch (error) {
      debugPrint('Could not save the capture ledger: $error');
    }
  }

  Future<void> removeFromInbox(CapturedMessage message) async {
    try {
      await remove(message.id);
    } catch (error) {
      debugPrint('Could not remove captured message ${message.id}: $error');
    }
  }

  var recovered = false;
  for (final message in messages) {
    if (seen.contains(message.id)) continue;
    final transactionId = capturedTransactionId(message);
    if (!isBooked(transactionId)) continue;
    try {
      final draft = draftFor(message, transactionId);
      if (draft == null) continue;
      seen.add(CaptureRecord.of(message, draft));
      recovered = true;
    } catch (error) {
      debugPrint('Could not recover captured message ${message.id}: $error');
    }
  }
  if (recovered) await saveSeen();

  /// Records [message] in [seen] and returns its draft when it is to be
  /// booked; null when there is nothing to book. Throws when the draft can't
  /// be built.
  FinanceTransaction? settle(CapturedMessage message) {
    if (seen.contains(message.id)) return null;
    final transactionId = capturedTransactionId(message);
    final draft = draftFor(message, transactionId);
    if (draft == null || draft.amount.amount <= Decimal.zero) return null;
    assert(draft.id == transactionId, 'draftFor must use the id it is given');
    final record = CaptureRecord.of(message, draft);
    if (alreadyBooked(transactionId)) {
      seen.add(record);
      return null;
    }
    final original = seen.originalOf(record);
    if (original != null) {
      seen.add(record.asDuplicateOf(original));
      return null;
    }
    seen.add(record);
    return draft;
  }

  final before = seen.records;
  final drafts = <FinanceTransaction>[];
  for (final message in messages) {
    try {
      final draft = settle(message);
      if (draft != null) drafts.add(draft);
    } catch (error) {
      debugPrint('Dropped captured message ${message.id}: $error');
    }
  }
  try {
    for (var at = 0; at < drafts.length; at += _maxBookedPerWrite) {
      final part = drafts.sublist(
        at,
        min(at + _maxBookedPerWrite, drafts.length),
      );
      await add(part);
      booked.addAll(part.map((draft) => draft.id));
    }
    await saveSeen();
    // Every message is settled now, so the queue never re-scans the same
    // text.
    for (final message in messages) {
      await removeFromInbox(message);
    }
    return booked.length;
  } catch (error) {
    debugPrint('Booking captured messages one at a time: $error');
    seen._records
      ..clear()
      ..addAll(before);
  }

  for (final message in messages) {
    final FinanceTransaction? draft;
    try {
      draft = settle(message);
    } catch (error) {
      debugPrint('Dropped captured message ${message.id}: $error');
      await removeFromInbox(message);
      continue;
    }
    if (draft != null) {
      try {
        await add([draft]);
        booked.add(draft.id);
      } catch (error) {
        seen._records.removeWhere((record) => record.id == message.id);
        if (error is! ArgumentError) {
          debugPrint('Kept captured message ${message.id} to retry: $error');
          continue;
        }
        debugPrint('Dropped captured message ${message.id}: $error');
      }
    }
    await saveSeen();
    await removeFromInbox(message);
  }
  return booked.length;
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

  /// The saved settings; off when they can't be read.
  static Future<TransactionCaptureSettings> load([
    SecureStorageService? storage,
  ]) async =>
      await tryLoad(storage) ??
      const TransactionCaptureSettings(enabled: false);

  /// Like [load], but null when the storage can't be read right now, so the
  /// processor can tell "off" from "unknown".
  static Future<TransactionCaptureSettings?> tryLoad([
    SecureStorageService? storage,
  ]) async {
    final String? raw;
    try {
      raw = await (storage ?? FlutterSecureStorageService()).read(_key);
    } catch (_) {
      return null;
    }
    if (raw == null || raw.isEmpty) {
      return const TransactionCaptureSettings(enabled: false);
    }
    try {
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

/// How long a message captured while the app runs waits before the inbox is
/// processed, so an SMS and the notification for it, which arrive together,
/// go through in one pass.
const _processDelay = Duration(seconds: 3);

final transactionCaptureServiceProvider = Provider<TransactionCaptureService>((
  ref,
) {
  Timer? pending;
  ref.onDispose(() => pending?.cancel());
  return TransactionCaptureService(
    onQueued: () {
      pending?.cancel();
      pending = Timer(_processDelay, () {
        ref.read(transactionCaptureProcessorProvider).processInbox().ignore();
      });
    },
  );
});

final transactionCaptureProcessorProvider = Provider<CapturedMessageProcessor>(
  (ref) => CapturedMessageProcessor(ref),
);
