import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Reloads the web page, which starts the app over from scratch. Returns true.
bool reloadPage() {
  globalContext
      .getProperty<JSObject>('location'.toJS)
      .callMethod<JSAny?>('reload'.toJS);
  return true;
}
