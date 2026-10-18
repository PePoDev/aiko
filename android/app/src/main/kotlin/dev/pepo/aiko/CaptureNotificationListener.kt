package dev.pepo.aiko

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

/**
 * Passes posted notifications to auto-capture in Dart (through [CaptureBridge]'s
 * event channel) inside Aiko's own process. Nothing is broadcast and no
 * receiver is exported, so other apps can neither read what passes through
 * here nor inject notifications of their own. Only what capture reads is
 * passed on: the posting app, the notification's key, its title and its
 * text. While capture isn't listening (switched off, or Aiko's engine isn't
 * running) nothing is passed on at all.
 *
 * The system binds this service once the user turns Aiko on under
 * "Notification access".
 */
class CaptureNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        // Called on the main thread, the only one the sink may be used from.
        val sink = sink ?: return
        // Aiko's own reminders quote amounts; they are never captured.
        if (sbn.packageName == packageName) return
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = (
            extras.getCharSequence(Notification.EXTRA_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            )?.toString()
        if (title.isNullOrBlank() && text.isNullOrBlank()) return
        sink.success(
            mapOf(
                "packageName" to sbn.packageName,
                "key" to sbn.key,
                "title" to title,
                "content" to text,
            ),
        )
    }

    companion object {
        /** Set while Dart listens; used on the main thread only. */
        var sink: EventChannel.EventSink? = null
    }
}
