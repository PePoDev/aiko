/// Calls [callback] when the device reports that it is back online. Only the
/// browser says so without a plugin; elsewhere this does nothing and callers
/// retry on their own schedule.
void onNetworkRestored(void Function() callback) {}
