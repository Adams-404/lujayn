package com.lujayn.lujayn

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

internal class ReminderAlarmReceiver : BroadcastReceiver() {
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

    fun show(context: Context, id: String, title: String, description: String) {
        createChannel(context)
        val openApp = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            id.hashCode(),
            openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(description.ifBlank { "It's time for your reminder." })
            .setStyle(
                Notification.BigTextStyle().bigText(
                    description.ifBlank { "It's time for your reminder." },
                ),
            )
            .setCategory(Notification.CATEGORY_REMINDER)
            .setPriority(Notification.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        runCatching {
            context.getSystemService(NotificationManager::class.java)
                .notify(id.hashCode(), notification)
        }
    }
}

internal class ReminderRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ReminderAlarmScheduler.rescheduleStored(context)
    }
}
