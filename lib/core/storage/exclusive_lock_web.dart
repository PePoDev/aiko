import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Runs [body] while holding the browser's Web Lock [name], so that only one
/// tab of the app runs it at a time (tabs share the app's databases). The
/// lock is let go when [body] completes or the tab closes. Without Web Locks
/// (an old browser, a page that isn't a secure context) it just runs [body].
Future<void> runExclusive(String name, Future<void> Function() body) async {
  final navigator = globalContext.getProperty<JSObject?>('navigator'.toJS);
  final locks = navigator?.getProperty<JSObject?>('locks'.toJS);
  if (locks == null) return body();
  var started = false;
  try {
    await locks
        .callMethod<JSPromise<JSAny?>>(
          'request'.toJS,
          name.toJS,
          ((JSAny? lock) {
            started = true;
            return body().toJS;
          }).toJS,
        )
        .toDart;
  } catch (_) {
    if (started) rethrow;
    // The lock couldn't be had at all: run unguarded rather than never.
    await body();
  }
}
