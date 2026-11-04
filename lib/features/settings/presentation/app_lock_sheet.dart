import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_lock_gate.dart';
import '../../../core/security/app_lock.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/layout/adaptive_presentation.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/profile.dart' show SecurityStatus;

/// This device's app lock state, for the Settings row.
final appLockStatusProvider = FutureProvider.autoDispose<SecurityStatus>(
  (ref) => ref.watch(appLockStoreProvider).status(),
);

/// Turns the app lock on (a new PIN), changes the PIN, turns fingerprint or
/// face unlock on or off, or turns the lock off ([AppLockStore]).
Future<void> showAppLockSheet(BuildContext context) {
  return showAikoSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AppLockSheet(),
  );
}

class _AppLockSheet extends ConsumerStatefulWidget {
  const _AppLockSheet();

  @override
  ConsumerState<_AppLockSheet> createState() => _AppLockSheetState();
}

class _AppLockSheetState extends ConsumerState<_AppLockSheet> {
  final _current = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();

  /// Null while loading.
  bool? _enabled;
  var _biometricsOn = false;
  var _biometricsAvailable = false;
  var _changing = false;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _current.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  AppLockStore get _store => ref.read(appLockStoreProvider);

  Future<void> _load() async {
    final enabled = await _store.isEnabled;
    final biometricsOn = await _store.usesBiometrics;
    final available = await ref.read(biometricUnlockProvider).isAvailable;
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _biometricsOn = biometricsOn;
      _biometricsAvailable = available;
    });
  }

  /// The new PIN when both fields hold the same 4–6 digits; otherwise shows
  /// why not and returns null.
  String? _newPin() {
    final l10n = context.l10n;
    final pin = _pin.text.trim();
    if (!AppLockStore.isValidPin(pin)) {
      setState(() => _error = l10n.appLockPinInvalid);
      return null;
    }
    if (pin != _confirm.text.trim()) {
      setState(() => _error = l10n.appLockPinMismatch);
      return null;
    }
    return pin;
  }

  /// Whether the current PIN field is right; otherwise shows why not.
  Future<bool> _currentPinOk() async {
    final l10n = context.l10n;
    final result = await _store.check(_current.text.trim());
    if (!mounted) return false;
    switch (result) {
      case PinAccepted():
        return true;
      case PinRejected(:final triesLeft):
        setState(() => _error = l10n.appLockWrongPin('$triesLeft'));
      case PinLockedOut(:final until):
        setState(
          () => _error = l10n.appLockWait(
            TimeOfDay.fromDateTime(until).format(context),
          ),
        );
    }
    _current.clear();
    return false;
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    String? done;
    try {
      done = await action();
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.appLockSaveFailed);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (done != null) {
      ref.invalidate(appLockStatusProvider);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    }
  }

  Future<void> _turnOn() => _run(() async {
    final pin = _newPin();
    if (pin == null) return null;
    await _store.setPin(pin);
    return mounted ? context.l10n.appLockTurnedOn : null;
  });

  Future<void> _changePin() => _run(() async {
    final pin = _newPin();
    if (pin == null || !await _currentPinOk()) return null;
    await _store.setPin(pin);
    return mounted ? context.l10n.appLockPinChanged : null;
  });

  Future<void> _turnOff() => _run(() async {
    if (!await _currentPinOk()) return null;
    await _store.disable();
    return mounted ? context.l10n.appLockTurnedOff : null;
  });

  Future<void> _setBiometrics(bool on) async {
    final l10n = context.l10n;
    // Turning it on proves the fingerprint or face works first.
    if (on &&
        !await ref
            .read(biometricUnlockProvider)
            .authenticate(l10n.appLockBiometricReason)) {
      if (mounted) setState(() => _error = l10n.appLockBiometricFailed);
      return;
    }
    await _store.setBiometrics(on);
    ref.invalidate(appLockStatusProvider);
    if (mounted) setState(() => _biometricsOn = on);
  }

  Widget _pinField(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final enabled = _enabled;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AikoSheetHandle(),
            Text(
              l10n.appLockSettingsTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.appLockIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (enabled == null)
              const Center(child: CircularProgressIndicator())
            else if (!enabled) ...[
              _pinField(_pin, l10n.appLockNewPin),
              _pinField(_confirm, l10n.appLockConfirmPin),
            ] else ...[
              if (_biometricsAvailable)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.fingerprint),
                  title: Text(l10n.appLockUseBiometrics),
                  value: _biometricsOn,
                  onChanged: _busy ? null : _setBiometrics,
                ),
              _pinField(_current, l10n.appLockCurrentPin),
              if (_changing) ...[
                _pinField(_pin, l10n.appLockNewPin),
                _pinField(_confirm, l10n.appLockConfirmPin),
              ],
            ],
            if (_error != null) ...[
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AikoColors.dangerRed,
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            if (enabled == false)
              FilledButton.icon(
                onPressed: _busy ? null : _turnOn,
                icon: const Icon(Icons.lock_outline),
                label: Text(l10n.appLockTurnOn),
              )
            else if (enabled == true) ...[
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : _changing
                    ? _changePin
                    : () => setState(() => _changing = true),
                icon: const Icon(Icons.password),
                label: Text(l10n.appLockChangePin),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AikoColors.dangerRed,
                ),
                onPressed: _busy ? null : _turnOff,
                icon: const Icon(Icons.lock_open_outlined),
                label: Text(l10n.appLockTurnOff),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
