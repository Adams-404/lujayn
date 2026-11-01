package com.lujayn.lujayn

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

internal object ReminderAlarmScheduler {
    private const val PREFERENCES = "lujayn_reminder_alarms"

    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        return alarmManager.canScheduleExactAlarms()
    }

    fun schedule(
        context: Context,
        id: String,
        title: String,
        description: String?,
        scheduledAtMillis: Long,
    ) {
        val data = JSONObject()
            .put("id", id)
            .put("title", title)
            .put("description", description ?: "")
            .put("scheduledAtMillis", scheduledAtMillis)

        preferences(context).edit().putString(id, data.toString()).apply()
        scheduleStored(context, data)
    }

    fun cancel(context: Context, id: String) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        alarmManager.cancel(pendingIntent(context, id))
        preferences(context).edit().remove(id).apply()
    }

    fun cancelAll(context: Context) {
        val prefs = preferences(context)
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        prefs.all.keys.forEach { id ->
            alarmManager.cancel(pendingIntent(context, id))
        }
        prefs.edit().clear().apply()
    }

    fun rescheduleStored(context: Context) {
        preferences(context).all.values.forEach { value ->
            val encoded = value as? String ?: return@forEach
            runCatching { JSONObject(encoded) }.getOrNull()?.let { data ->
                if (data.optLong("scheduledAtMillis") > System.currentTimeMillis()) {
                    scheduleStored(context, data)
                }
            }
        }
    }

    fun removeStored(context: Context, id: String) {
        preferences(context).edit().remove(id).apply()
    }

    private fun scheduleStored(context: Context, data: JSONObject) {
        val id = data.getString("id")
        val triggerAt = data.getLong("scheduledAtMillis")
        if (triggerAt <= System.currentTimeMillis()) return

        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            putExtra(ReminderAlarmReceiver.EXTRA_ID, id)
            putExtra(ReminderAlarmReceiver.EXTRA_TITLE, data.optString("title"))
            putExtra(ReminderAlarmReceiver.EXTRA_DESCRIPTION, data.optString("description"))
        }
        intent.action = alarmAction(id)
        val broadcast = PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (canScheduleExactAlarms(context)) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    broadcast,
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    broadcast,
                )
            }
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, broadcast)
        }
    }

    private fun pendingIntent(context: Context, id: String): PendingIntent {
        val intent = Intent(context, ReminderAlarmReceiver::class.java)
            .setAction(alarmAction(id))
        return PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun alarmAction(id: String) = "com.lujayn.REMINDER_ALARM.$id"

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
}
