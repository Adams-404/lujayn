package com.lujayn.lujayn

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(EXTRA_ID) ?: return
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Reminder"
        val description = intent.getStringExtra(EXTRA_DESCRIPTION).orEmpty()

        // Ringing is owned by a foreground service so the sound survives this
        // receiver returning and the device sleeping. The notification is a
        // fallback if Android refuses to start the service.
        ReminderRingingService.start(context, id, title, description)
        ReminderNotifications.show(context, id, title, description)
        ReminderAlarmScheduler.onAlarmDelivered(context, id)
    }

    companion object {
        const val EXTRA_ID = "reminder_id"
        const val EXTRA_TITLE = "reminder_title"
        const val EXTRA_DESCRIPTION = "reminder_description"
    }
}

/** Routes CallStyle answer/decline actions into Lujayn's reminder flow. */
class ReminderCallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(ReminderAlarmReceiver.EXTRA_ID) ?: return
        val notifications = context.getSystemService(NotificationManager::class.java)
        notifications.cancel(id.hashCode())

        ReminderRingingService.stop(context)

        if (intent.action == ACTION_ANSWER) {
            val openApp = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(ReminderAlarmReceiver.EXTRA_ID, id)
                putExtra(
                    ReminderAlarmReceiver.EXTRA_TITLE,
                    intent.getStringExtra(ReminderAlarmReceiver.EXTRA_TITLE),
                )
                putExtra(
                    ReminderAlarmReceiver.EXTRA_DESCRIPTION,
                    intent.getStringExtra(ReminderAlarmReceiver.EXTRA_DESCRIPTION),
                )
            }
            context.startActivity(openApp)
        } else {
            // Declining happens while Flutter may not be running. Record it so
            // the reminder is dismissed the next time the app opens.
            ReminderRingtoneStore.addDeclined(context, id)
        }
    }

    companion object {
        const val ACTION_ANSWER = "com.lujayn.REMINDER_CALL_ANSWER"
        const val ACTION_DECLINE = "com.lujayn.REMINDER_CALL_DECLINE"
    }
}

internal object ReminderNotifications {
    /**
     * Call alerts live on their own silent channel: the ringing service plays
     * the chosen ringtone, and a channel sound would play a second one over it.
     * Missed reminders keep the ordinary channel so they still make a sound.
     */
    private const val CHANNEL_CALLS = "reminder_calls_v2"
    private const val CHANNEL_REMINDERS = "reminders"

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)

        val calls = android.app.NotificationChannel(
            CHANNEL_CALLS,
            "Reminder calls",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Ringing reminder calls from Lujayn"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(calls)

        val reminders = android.app.NotificationChannel(
            CHANNEL_REMINDERS,
            "Reminders",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Scheduled reminders from Lujayn"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(reminders)
    }

    fun show(
        context: Context,
        id: String,
        title: String,
        description: String,
        missed: Boolean = false,
    ) {
        runCatching {
            context.getSystemService(NotificationManager::class.java)
                .notify(id.hashCode(), build(context, id, title, description, missed))
        }
    }

    /** Builds the call or missed-call notification for both the service and fallback. */
    fun build(
        context: Context,
        id: String,
        title: String,
        description: String,
        missed: Boolean = false,
    ): Notification {
        createChannel(context)
        val openApp = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(ReminderAlarmReceiver.EXTRA_ID, id)
            putExtra(ReminderAlarmReceiver.EXTRA_TITLE, title)
            putExtra(ReminderAlarmReceiver.EXTRA_DESCRIPTION, description)
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            id.hashCode(),
            openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val answerIntent = PendingIntent.getBroadcast(
            context,
            id.hashCode() + 1,
            Intent(context, ReminderCallActionReceiver::class.java).apply {
                action = ReminderCallActionReceiver.ACTION_ANSWER
                putExtra(ReminderAlarmReceiver.EXTRA_ID, id)
                putExtra(ReminderAlarmReceiver.EXTRA_TITLE, title)
                putExtra(ReminderAlarmReceiver.EXTRA_DESCRIPTION, description)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val declineIntent = PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            Intent(context, ReminderCallActionReceiver::class.java).apply {
                action = ReminderCallActionReceiver.ACTION_DECLINE
                putExtra(ReminderAlarmReceiver.EXTRA_ID, id)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, if (missed) CHANNEL_REMINDERS else CHANNEL_CALLS)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val body = description.ifBlank { "It's time for your reminder." }
        builder
            .setSmallIcon(R.drawable.ic_stat_lujayn)
            .setContentTitle(if (missed) "Missed: $title" else title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(if (missed) Notification.CATEGORY_REMINDER else Notification.CATEGORY_CALL)
            .setPriority(Notification.PRIORITY_MAX)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(!missed)
            .setAutoCancel(missed)
            .setContentIntent(contentIntent)

        if (!missed) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val caller = android.app.Person.Builder()
                    .setName(title)
                    .setImportant(true)
                    .build()
                builder.setStyle(
                    Notification.CallStyle.forIncomingCall(
                        caller,
                        answerIntent,
                        declineIntent,
                    ).setIsVideo(false),
                )
            } else {
                // CallStyle only exists from Android 12. Older phones still get
                // real Answer and Decline buttons instead of a plain reminder.
                @Suppress("DEPRECATION")
                builder
                    .addAction(
                        Notification.Action.Builder(
                            Icon.createWithResource(context, R.drawable.ic_stat_lujayn),
                            "Answer",
                            answerIntent,
                        ).build(),
                    )
                    .addAction(
                        Notification.Action.Builder(
                            Icon.createWithResource(context, R.drawable.ic_stat_lujayn),
                            "Decline",
                            declineIntent,
                        ).build(),
                    )
            }
        }

        // Android may refuse full-screen presentation. In that case the
        // incoming-call notification remains tappable and opens Lujayn.
        if (!missed && canUseFullScreenIntent(context)) {
            builder.setFullScreenIntent(contentIntent, true)
        }
        return builder.build()
    }

    /** Full-screen intents need an explicit grant from Android 14 onwards. */
    fun canUseFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return true
        }
        return context.getSystemService(NotificationManager::class.java)
            .canUseFullScreenIntent()
    }
}

class ReminderRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ReminderAlarmScheduler.rescheduleStored(context)
    }
}
