import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Calls [callback] whenever the browser fires its `online` event.
void onNetworkRestored(void Function() callback) {
  globalContext.callMethod(
    'addEventListener'.toJS,
    'online'.toJS,
    ((JSAny? _) => callback()).toJS,
  );
}
