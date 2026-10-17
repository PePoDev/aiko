import 'dart:async';

/// Runs app startup with a time limit, so a step that never finishes (on the
/// web, for example, a Firebase SDK download that failed) ends in the startup
/// error screen instead of a blank page.
///
/// A retry while a timed-out attempt is still running waits for that attempt
/// instead of starting a second one next to it; a failed attempt is started
/// again.
class StartupGuard {
  StartupGuard(this._initialize, {this.timeout = defaultTimeout});

  /// Generous: a first web visit on a slow connection downloads the Firebase
  /// SDK and the database engine within this time.
  static const defaultTimeout = Duration(seconds: 20);

  final Future<void> Function() _initialize;
  final Duration timeout;

  Future<void>? _attempt;
  var _running = false;

  /// The attempt still running after [run] timed out, or null.
  Future<void>? get running => _running ? _attempt : null;

  /// Starts up, or joins the attempt already running. Completes when startup
  /// has finished; throws its error, or a [TimeoutException] after [timeout].
  Future<void> run() {
    var attempt = _attempt;
    if (attempt == null) {
      _running = true;
      attempt = _attempt = Future<void>.sync(_initialize);
      final started = attempt;
      started.then<void>(
        (_) => _running = false,
        onError: (Object _) {
          _running = false;
          if (identical(_attempt, started)) _attempt = null;
        },
      );
    }
    return attempt.timeout(timeout);
  }
}
