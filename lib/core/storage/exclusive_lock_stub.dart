/// Runs [body]. Only the browser can run the app in several places at once
/// (tabs); one app process elsewhere needs no lock across them.
Future<void> runExclusive(String name, Future<void> Function() body) => body();
