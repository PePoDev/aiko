package dev.pepo.aiko

import android.app.Activity
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Auto-capture's channels to Dart (TransactionCaptureService in
 * lib/features/transaction_capture/transaction_capture.dart): notification
 * access, the [CaptureSmsReceiver] switch, and the notifications
 * [CaptureNotificationListener] passes on. Lives with [MainActivity]'s engine.
 */
class CaptureBridge(private val activity: Activity) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private var methods: MethodChannel? = null
    private var notifications: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private var pendingAccess: MethodChannel.Result? = null

    fun attach(messenger: BinaryMessenger) {
        methods = MethodChannel(messenger, METHODS).also { it.setMethodCallHandler(this) }
        notifications = EventChannel(messenger, NOTIFICATIONS).also { it.setStreamHandler(this) }
    }

    fun detach() {
        methods?.setMethodCallHandler(null)
        notifications?.setStreamHandler(null)
        methods = null
        notifications = null
        onCancel(null)
        // The engine is going away; there is no one left to answer.
        pendingAccess = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "notificationAccessGranted" -> result.success(notificationAccessGranted())
            "requestNotificationAccess" -> requestNotificationAccess(result)
            "setSmsReceiverEnabled" -> {
                setSmsReceiverEnabled(call.arguments == true)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun notificationAccessGranted(): Boolean {
        val listener = ComponentName(activity, CaptureNotificationListener::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            return activity.getSystemService(NotificationManager::class.java)
                ?.isNotificationListenerAccessGranted(listener) == true
        }
        val enabled = Settings.Secure.getString(
            activity.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == listener }
    }

    /** Opens the system "Notification access" screen; answers once the user is back. */
    private fun requestNotificationAccess(result: MethodChannel.Result) {
        pendingAccess?.success(notificationAccessGranted())
        pendingAccess = null
        try {
            activity.startActivityForResult(
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS),
                REQUEST_NOTIFICATION_ACCESS,
            )
            pendingAccess = result
        } catch (e: ActivityNotFoundException) {
            result.success(false)
        }
    }

    /** From [MainActivity.onActivityResult]; true when it was this bridge's request. */
    fun onActivityResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_NOTIFICATION_ACCESS) return false
        pendingAccess?.success(notificationAccessGranted())
        pendingAccess = null
        return true
    }

    private fun setSmsReceiverEnabled(enabled: Boolean) {
        activity.packageManager.setComponentEnabledSetting(
            ComponentName(activity, CaptureSmsReceiver::class.java),
            if (enabled) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            },
            // Without it, changing a component's state kills the app.
            PackageManager.DONT_KILL_APP,
        )
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        CaptureNotificationListener.sink = events
    }

    override fun onCancel(arguments: Any?) {
        if (CaptureNotificationListener.sink === sink) CaptureNotificationListener.sink = null
        sink = null
    }

    private companion object {
        const val METHODS = "dev.pepo.aiko/capture"
        const val NOTIFICATIONS = "dev.pepo.aiko/capture/notifications"
        const val REQUEST_NOTIFICATION_ACCESS = 7301
    }
}
