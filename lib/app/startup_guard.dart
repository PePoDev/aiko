import 'dart:async';

/// Runs app startup with a time limit, so a step that never finishes (on the
/// web, for example, a Firebase SDK download that failed) ends in the startup
/// error screen instead of a blank page.
///
/// A retry while a timed-out attempt is still running waits for that attempt
/// instead of starting a second one next to it; a failed attempt is started
/// again.
class StartupGuard {
  StartupGuard(
    this._initialize, {
    this.timeout = defaultTimeout,
    this.stuckAfter = defaultStuckAfter,
    this.onLateError,
  });

  /// Generous: a slow connection gets this long for the web's first-visit
  /// downloads (Firebase SDK, database engine) and for Firebase Auth to
  /// confirm a signed-in user, whose requests each wait up to 30 s.
  static const defaultTimeout = Duration(seconds: 45);

  /// How long an attempt runs before it is treated as stuck rather than
  /// slow; see [waitUnlessStuck].
  static const defaultStuckAfter = Duration(seconds: 90);

  final Future<void> Function() _initialize;

  /// How long [run] waits before it reports a slow start.
  final Duration timeout;

  /// See [waitUnlessStuck].
  final Duration stuckAfter;

  /// Gets the error of an attempt that fails after [run] timed out, which
  /// nothing else sees.
  final void Function(Object error, StackTrace stackTrace)? onLateError;

  Future<void>? _attempt;
  var _running = false;
  var _timedOut = false;
  var _done = false;
  final _clock = Stopwatch();

  /// The attempt still running after [run] timed out, or null.
  Future<void>? get running => _running ? _attempt : null;

  /// Whether startup has finished successfully.
  bool get done => _done;

  /// Starts up, or joins the attempt already running. Completes when startup
  /// has finished; throws its error, or a [TimeoutException] after [timeout].
  Future<void> run() {
    var attempt = _attempt;
    if (attempt == null) {
      _running = true;
      _timedOut = false;
      _clock
        ..reset()
        ..start();
      attempt = _attempt = Future<void>.sync(_initialize);
      final started = attempt;
      started.then<void>(
        (_) {
          _running = false;
          _done = true;
        },
        onError: (Object error, StackTrace stackTrace) {
          _running = false;
          if (identical(_attempt, started)) _attempt = null;
          if (_timedOut) onLateError?.call(error, stackTrace);
        },
      );
    }
    final current = attempt;
    return current.timeout(
      timeout,
      onTimeout: () {
        if (identical(_attempt, current) && _running) _timedOut = true;
        throw TimeoutException(
          'Startup is taking longer than $timeout',
          timeout,
        );
      },
    );
  }

  /// Waits for the attempt still running after a timeout (see [running]) to
  /// end, but only until it has run for [stuckAfter] in all: a slow start is
  /// worth waiting for, one still running then is probably stuck. Afterwards
  /// [done] says whether startup finished, and [running] whether it still
  /// runs.
  Future<void> waitUnlessStuck() async {
    final attempt = running;
    if (attempt == null) return;
    final left = stuckAfter - _clock.elapsed;
    if (left <= Duration.zero) return;
    await attempt
        .then<void>((_) {}, onError: (Object _) {})
        .timeout(left, onTimeout: () {});
  }
}
