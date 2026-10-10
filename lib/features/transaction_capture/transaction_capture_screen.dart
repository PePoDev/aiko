import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/aiko_data_widgets.dart';
import '../accounts/domain/account.dart';
import 'transaction_capture.dart';

/// Settings for reading bank SMS + other apps' notifications and turning them
/// into transactions automatically. Android-only.
class TransactionCaptureScreen extends ConsumerStatefulWidget {
  const TransactionCaptureScreen({super.key});

  @override
  ConsumerState<TransactionCaptureScreen> createState() =>
      _TransactionCaptureScreenState();
}

class _TransactionCaptureScreenState
    extends ConsumerState<TransactionCaptureScreen> {
  TransactionCaptureSettings _settings = const TransactionCaptureSettings(
    enabled: false,
  );
  bool _notificationsGranted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await TransactionCaptureSettings.load();
    final granted = await ref
        .read(transactionCaptureServiceProvider)
        .notificationsGranted();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _notificationsGranted = granted;
      _loading = false;
    });
  }

  Future<void> _persist(TransactionCaptureSettings next) async {
    setState(() => _settings = next);
    await next.save();
    final service = ref.read(transactionCaptureServiceProvider);
    if (next.enabled) {
      await service.start();
    } else {
      await service.stop();
    }
  }

  Future<void> _grantNotifications() async {
    await ref.read(transactionCaptureServiceProvider).requestNotifications();
    await _load();
  }

  Future<void> _grantSms() async {
    final granted = await ref
        .read(transactionCaptureServiceProvider)
        .requestSms();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? context.l10n.captureSmsGranted
              : context.l10n.captureSmsDenied,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Capture relies on Android-only OS access; on other platforms the controls
    // render disabled rather than functional.
    final android =
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.captureTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AikoInlineNotice(
            title: context.l10n.captureHowItWorks,
            message: context.l10n.captureHowItWorksBody,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.captureEnable),
            subtitle: Text(context.l10n.captureEnableSubtitle),
            value: android && _settings.enabled,
            onChanged: android
                ? (value) => _persist(_settings.copyWith(enabled: value))
                : null,
          ),
          const Divider(),
          ListTile(
            enabled: android,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(context.l10n.captureNotificationAccess),
            subtitle: Text(
              _notificationsGranted
                  ? context.l10n.captureGranted
                  : context.l10n.captureNotGranted,
            ),
            trailing: FilledButton(
              onPressed: !android || _notificationsGranted
                  ? null
                  : _grantNotifications,
              child: Text(context.l10n.captureGrant),
            ),
          ),
          ListTile(
            enabled: android,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sms_outlined),
            title: Text(context.l10n.captureSmsAccess),
            subtitle: Text(context.l10n.captureSmsAccessSubtitle),
            trailing: FilledButton(
              onPressed: android ? _grantSms : null,
              child: Text(context.l10n.captureGrant),
            ),
          ),
          const Divider(),
          ListTile(
            enabled: android,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(context.l10n.captureAccount),
            subtitle: Text(
              accounts
                      .where((a) => a.id == _settings.accountId)
                      .map((a) => a.name)
                      .firstOrNull ??
                  context.l10n.captureAccountRequired,
            ),
            trailing: DropdownButton<String>(
              value: accounts.any((a) => a.id == _settings.accountId)
                  ? _settings.accountId
                  : null,
              hint: Text(context.l10n.select),
              items: [
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: android
                  ? (value) {
                      if (value != null) {
                        _persist(_settings.copyWith(accountId: value));
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
