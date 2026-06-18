import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../shared/widgets/aiko_data_widgets.dart';
import '../../theme/aiko_colors.dart';
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
        content: Text(granted ? 'SMS access granted' : 'SMS access denied'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Auto-capture')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: AikoInlineNotice(
            title: 'Android only',
            icon: Icons.info_outline,
            accentColor: AikoColors.warningOrange,
            message:
                'Reading SMS and other apps’ notifications is only possible '
                'on Android. iOS does not allow it.',
          ),
        ),
      );
    }

    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Auto-capture')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const AikoInlineNotice(
            title: 'How auto-capture works',
            message:
                'Aiko reads incoming bank SMS and banking/wallet notifications, '
                'extracts the amount, and logs a transaction on your chosen '
                'account. Parsing is best-effort — review captured entries.',
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable auto-capture'),
            subtitle: const Text('Listen for new SMS and notifications'),
            value: _settings.enabled,
            onChanged: (value) => _persist(_settings.copyWith(enabled: value)),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Notification access'),
            subtitle: Text(_notificationsGranted ? 'Granted' : 'Not granted'),
            trailing: FilledButton(
              onPressed: _notificationsGranted ? null : _grantNotifications,
              child: const Text('Grant'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sms_outlined),
            title: const Text('SMS access'),
            subtitle: const Text('Read incoming bank SMS'),
            trailing: FilledButton(
              onPressed: _grantSms,
              child: const Text('Grant'),
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Capture account'),
            subtitle: Text(
              accounts
                      .where((a) => a.id == _settings.accountId)
                      .map((a) => a.name)
                      .firstOrNull ??
                  'Required — pick where captured transactions land',
            ),
            trailing: DropdownButton<String>(
              value: accounts.any((a) => a.id == _settings.accountId)
                  ? _settings.accountId
                  : null,
              hint: const Text('Select'),
              items: [
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _persist(_settings.copyWith(accountId: value));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
