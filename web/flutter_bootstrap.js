{{flutter_js}}
{{flutter_build_config}}

// Starts the app without Flutter's deprecated service worker (it only
// unregisters itself); index.html registers Aiko's own, aiko_sw.js.
_flutter.loader.load();
