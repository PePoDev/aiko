import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/firebase/firebase_backend.dart';
import '../core/security/app_lock.dart';
import '../core/security/biometric_unlock.dart';
import '../core/storage/secure_storage_service.dart';
import '../features/auth/data/auth_repository.dart';
import '../l10n/l10n.dart';
import '../theme/aiko_colors.dart';
import 'user_session.dart';

/// This device's app lock; overridden in tests.
final appLockStoreProvider = Provider<AppLockStore>(
  (ref) => AppLockStore(FlutterSecureStorageService()),
);

/// Fingerprint or face unlock; overridden in tests.
final biometricUnlockProvider = Provider<BiometricUnlock>(
  (ref) => const BiometricUnlock(),
);

/// Covers the app with the lock screen while this device's app lock is on
/// ([AppLockStore]): when the app starts, and when it comes back after
/// [relockAfter] or more in the background.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  static const relockAfter = Duration(minutes: 1);

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  /// Null until it's known whether the lock is on: nothing shows meanwhile.
  bool? _locked;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockIfEnabled();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _lockIfEnabled() async {
    bool enabled;
    try {
      enabled = await ref.read(appLockStoreProvider).isEnabled;
    } catch (_) {
      // Unreadable storage can't hold a PIN to check against.
      enabled = false;
    }
    if (mounted) setState(() => _locked = enabled || (_locked ?? false));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _leftAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final leftAt = _leftAt;
        _leftAt = null;
        if (_locked == false &&
            leftAt != null &&
            DateTime.now().difference(leftAt) >= AppLockGate.relockAfter) {
          _lockIfEnabled();
        }
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _locked;
    if (locked == null) {
      return ColoredBox(color: Theme.of(context).colorScheme.surface);
    }
    return Stack(
      children: [
        // Hidden from screen readers and animations while locked.
        ExcludeSemantics(
          excluding: locked,
          child: TickerMode(enabled: !locked, child: widget.child),
        ),
        if (locked)
          Positioned.fill(
            // Its own navigator: the lock sits above the app's, and its
            // dialogs and tooltips need one.
            // (Without the app's hero animations, which belong to its own
            // navigator.)
            child: HeroControllerScope.none(
              child: Navigator(
                onGenerateRoute: (_) => PageRouteBuilder<void>(
                  pageBuilder: (_, _, _) => _LockScreen(
                    onUnlocked: () => setState(() => _locked = false),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A PIN keypad (no system keyboard to cover it; a physical keyboard works
/// too), with fingerprint or face unlock when it's on.
class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen({required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  static const _maxDigits = 6;

  final _focus = FocusNode();
  var _pin = '';
  String? _message;
  DateTime? _waitUntil;
  Timer? _waitTimer;
  var _checking = false;
  var _biometrics = false;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
    _prepare();
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final store = ref.read(appLockStoreProvider);
    _startWait(await store.lockedUntil());
    final biometrics =
        await store.usesBiometrics &&
        await ref.read(biometricUnlockProvider).isAvailable;
    if (!mounted) return;
    setState(() => _biometrics = biometrics);
    if (biometrics) _useBiometrics();
  }

  void _startWait(DateTime? until) {
    _waitTimer?.cancel();
    _waitUntil = until;
    if (until == null) return;
    _waitTimer = Timer(until.difference(DateTime.now()), () {
      if (mounted) setState(() => _waitUntil = _message = null);
    });
  }

  bool get _waiting => _waitUntil != null;

  Future<void> _useBiometrics() async {
    final l10n = context.l10n;
    final ok = await ref
        .read(biometricUnlockProvider)
        .authenticate(l10n.appLockBiometricReason);
    if (!mounted) return;
    if (ok) {
      await ref.read(appLockStoreProvider).unlocked();
      widget.onUnlocked();
    } else {
      setState(() => _message = l10n.appLockBiometricFailed);
    }
  }

  void _type(String digit) {
    if (_waiting || _checking || _pin.length >= _maxDigits) return;
    setState(() {
      _pin += digit;
      _message = null;
    });
  }

  void _erase() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_waiting || _checking || !AppLockStore.isValidPin(_pin)) return;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    setState(() => _checking = true);
    final result = await ref.read(appLockStoreProvider).check(_pin);
    if (!mounted) return;
    switch (result) {
      case PinAccepted():
        widget.onUnlocked();
        return;
      case PinRejected(:final triesLeft):
        _message = l10n.appLockWrongPin('$triesLeft');
      case PinLockedOut(:final until):
        _message = l10n.appLockWait(DateFormat.Hms(locale).format(until));
        _startWait(until);
    }
    setState(() {
      _checking = false;
      _pin = '';
    });
  }

  Future<void> _forgot() async {
    final l10n = context.l10n;
    final signedIn = FirebaseBackend.userId != null;
    final signOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.appLockForgot),
        content: Text(
          signedIn ? l10n.appLockForgotSignedIn : l10n.appLockForgotLocal,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(signedIn ? l10n.cancel : l10n.close),
          ),
          if (signedIn)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.appLockSignOut),
            ),
        ],
      ),
    );
    if (signOut != true || !mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await AuthRepository().signOut();
      // The lock guarded that account's data; the next one sets its own.
      await ref.read(appLockStoreProvider).disable();
      invalidateUserData(container.invalidate);
      if (mounted) widget.onUnlocked();
    } catch (_) {
      if (mounted) setState(() => _message = l10n.profileLogOutFailed);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final character = event.character;
    if (character != null && RegExp(r'^\d$').hasMatch(character)) {
      _type(character);
    } else if (key == LogicalKeyboardKey.backspace) {
      _erase();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final enabled = !_waiting && !_checking;
    Widget key(String digit) => _KeypadButton(
      label: digit,
      onPressed: enabled ? () => _type(digit) : null,
    );
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 40,
                      color: AikoColors.primaryBlue,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.appLockLockedTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.appLockEnterPin,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      label: l10n.appLockDigitsEntered('${_pin.length}'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _maxDigits; i++)
                            Container(
                              width: 14,
                              height: 14,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < _pin.length
                                    ? AikoColors.primaryBlue
                                    : null,
                                border: Border.all(
                                  color: i < _pin.length
                                      ? AikoColors.primaryBlue
                                      : theme.colorScheme.outline,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: Center(
                        child: Text(
                          _message ?? '',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AikoColors.dangerRed,
                          ),
                        ),
                      ),
                    ),
                    for (final row in const [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                    ])
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [for (final digit in row) key(digit)],
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _KeypadButton(
                          icon: Icons.backspace_outlined,
                          tooltip: l10n.appLockErase,
                          onPressed: enabled ? _erase : null,
                        ),
                        key('0'),
                        _KeypadButton(
                          icon: Icons.check,
                          tooltip: l10n.appLockUnlock,
                          onPressed: enabled && AppLockStore.isValidPin(_pin)
                              ? _submit
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_biometrics)
                      OutlinedButton.icon(
                        onPressed: _useBiometrics,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(l10n.appLockUseBiometrics),
                      ),
                    TextButton(
                      onPressed: _forgot,
                      child: Text(l10n.appLockForgot),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    this.label,
    this.icon,
    this.tooltip,
    required this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: 72,
        height: 64,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(shape: const StadiumBorder()),
          child: icon != null
              ? Icon(icon)
              : Text(label!, style: Theme.of(context).textTheme.headlineSmall),
        ),
      ),
    );
    return tooltip == null
        ? child
        : Tooltip(
            message: tooltip,
            child: Semantics(label: tooltip, button: true, child: child),
          );
  }
}
