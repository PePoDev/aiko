// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/widgets.dart';

/// Small ergonomic helpers for `BuildContext`. The most common
/// pattern in this codebase is
/// `if (mounted) setState(() { ... });`, repeated in dozens of places; this
/// extension collapses it to a single, easier-to-read call.
extension BuildContextX on BuildContext {
  /// Runs [fn] inside `setState` only when the [State] owning this [Element]
  /// is still mounted. Safe to call from async callbacks (e.g. after a
  /// repository future completes) without re-checking `mounted` by hand.
  void safeSetState(VoidCallback fn) {
    final state = findAncestorStateOfType<State>();
    if (state == null || !state.mounted) return;
    state.setState(fn);
  }
}
