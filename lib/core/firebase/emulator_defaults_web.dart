import 'dart:js_interop';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_web/firebase_core_web.dart';

@JS('aikoPrepareFirebaseEmulator')
external JSPromise<JSAny?> _prepare(
  JSObject options,
  JSString host,
  JSString version,
);

/// FlutterFire restores Auth inside initializeApp, before useAuthEmulator can
/// run. Prepare that same JS Auth instance first to restore emulator sessions
/// safely in release builds. The helper uses FlutterFire's SDK version/options.
Future<void> configureAuthEmulatorBeforeInitialization(
  FirebaseOptions options,
  String host,
) async {
  await _prepare(
    {
          'apiKey': options.apiKey,
          'appId': options.appId,
          'projectId': options.projectId,
          'authDomain': options.authDomain,
          'storageBucket': options.storageBucket,
          'messagingSenderId': options.messagingSenderId,
        }.jsify()
        as JSObject,
    host.toJS,
    supportedFirebaseJsSdkVersion.toJS,
  ).toDart;
}
