package com.lujayn.lujayn

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(EXTRA_ID) ?: return
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Reminder"
        val description = intent.getStringExtra(EXTRA_DESCRIPTION).orEmpty()

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
        }
    }

    companion object {
        const val ACTION_ANSWER = "com.lujayn.REMINDER_CALL_ANSWER"
        const val ACTION_DECLINE = "com.lujayn.REMINDER_CALL_DECLINE"
    }
}

internal object ReminderNotifications {
    private const val CHANNEL_ID = "reminders"

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                CHANNEL_ID,
                "Reminders",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Scheduled reminders from Lujayn"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    fun show(
        context: Context,
        id: String,
        title: String,
        description: String,
        missed: Boolean = false,
    ) {
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
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val body = description.ifBlank { "It's time for your reminder." }
        val notificationBuilder = builder
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

        if (!missed && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val caller = android.app.Person.Builder()
                .setName(title)
                .setImportant(true)
                .build()
            val callStyle = Notification.CallStyle.forIncomingCall(
                caller,
                answerIntent,
                declineIntent,
            ).setIsVideo(false)
            notificationBuilder.setStyle(callStyle)
        }

        // Android may refuse full-screen presentation. In that case the
        // incoming-call notification remains tappable and opens Lujayn.
        if (!missed && canUseFullScreenIntent(context)) {
            notificationBuilder.setFullScreenIntent(contentIntent, true)
        }

        runCatching {
            context.getSystemService(NotificationManager::class.java)
                .notify(id.hashCode(), notificationBuilder.build())
        }
    }

    /** Full-screen intents need an explicit grant from Android 14 onwards. */
    private fun canUseFullScreenIntent(context: Context): Boolean {
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
