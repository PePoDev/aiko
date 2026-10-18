package dev.pepo.aiko

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.shounakmulay.telephony.sms.IncomingSmsReceiver
import com.shounakmulay.telephony.utils.Constants
import io.flutter.FlutterInjector
import io.flutter.view.FlutterCallbackInformation

/**
 * Receives incoming SMS for auto-capture and hands them to another_telephony's
 * receiver, which passes them to the Dart listener (app in front) or to
 * captureSmsBackgroundHandler in a background isolate.
 *
 * Declared disabled: [CaptureBridge] enables it when capture starts and
 * disables it when capture stops, so no SMS wakes Aiko while capture is off.
 *
 * The plugin starts its background isolate from the entry point Dart stored
 * with listenIncomingSms, and crashes the app when none is stored (capture
 * never started, or the SMS permission was granted later). SMS are only
 * handed on once a stored entry point resolves.
 */
class CaptureSmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (!hasBackgroundEntryPoint(context)) return
        IncomingSmsReceiver().onReceive(context, intent)
    }

    private fun hasBackgroundEntryPoint(context: Context): Boolean {
        val handle = context
            .getSharedPreferences(Constants.SHARED_PREFERENCES_NAME, Context.MODE_PRIVATE)
            .getLong(Constants.SHARED_PREFS_BACKGROUND_SETUP_HANDLE, 0)
        if (handle == 0L) return false
        // Looking the handle up needs the engine loaded, as the plugin does
        // before starting its isolate (a no-op when the app is running).
        val app = context.applicationContext
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(app)
        loader.ensureInitializationComplete(app, null)
        return FlutterCallbackInformation.lookupCallbackInformation(handle) != null
    }
}
