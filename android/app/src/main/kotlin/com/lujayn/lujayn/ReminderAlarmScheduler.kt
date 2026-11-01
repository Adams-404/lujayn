package com.lujayn.lujayn

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

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
        recurrenceType: String,
        daysOfWeek: List<Int>,
        localYear: Int,
        localMonth: Int,
        localDay: Int,
        localHour: Int,
        localMinute: Int,
    ) {
        val data = JSONObject()
            .put("id", id)
            .put("title", title)
            .put("description", description ?: "")
            .put("scheduledAtMillis", scheduledAtMillis)
            .put("recurrenceType", recurrenceType)
            .put("daysOfWeek", JSONArray(daysOfWeek))
            .put("localYear", localYear)
            .put("localMonth", localMonth)
            .put("localDay", localDay)
            .put("localHour", localHour)
            .put("localMinute", localMinute)

        preferences(context).edit().putString(id, data.toString()).apply()
        scheduleStored(context, data)
    }

    fun cancel(context: Context, id: String) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        pendingIntent(context, id)?.let(alarmManager::cancel)
        preferences(context).edit().remove(id).apply()
    }

    fun cancelAll(context: Context) {
        val prefs = preferences(context)
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        prefs.all.keys.forEach { id ->
            pendingIntent(context, id)?.let(alarmManager::cancel)
        }
        prefs.edit().clear().apply()
    }

    fun rescheduleStored(context: Context) {
        val prefs = preferences(context)
        prefs.all.forEach { (id, value) ->
            val encoded = value as? String ?: return@forEach
            val data = runCatching { JSONObject(encoded) }.getOrNull()
                ?: return@forEach
            val now = System.currentTimeMillis()
            val next = nextOccurrence(data, now, includeCurrent = true)
            if (next == null) {
                prefs.edit().remove(id).apply()
            } else {
                data.put("scheduledAtMillis", next)
                prefs.edit().putString(id, data.toString()).apply()
                scheduleStored(context, data)
            }
        }
    }

    fun onAlarmDelivered(context: Context, id: String) {
        val prefs = preferences(context)
        val encoded = prefs.getString(id, null) ?: return
        val data = runCatching { JSONObject(encoded) }.getOrNull() ?: return
        val next = nextOccurrence(data, System.currentTimeMillis())
        if (next == null) {
            prefs.edit().remove(id).apply()
        } else {
            data.put("scheduledAtMillis", next)
            prefs.edit().putString(id, data.toString()).apply()
            scheduleStored(context, data)
        }
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

    private fun pendingIntent(context: Context, id: String): PendingIntent? {
        val intent = Intent(context, ReminderAlarmReceiver::class.java)
            .setAction(alarmAction(id))
        return PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun nextOccurrence(
        data: JSONObject,
        afterMillis: Long,
        includeCurrent: Boolean = false,
    ): Long? {
        val recurrence = data.optString("recurrenceType", "none")
        val candidate = Calendar.getInstance().apply {
            clear()
            set(
                data.optInt("localYear"),
                data.optInt("localMonth") - 1,
                data.optInt("localDay"),
                data.optInt("localHour"),
                data.optInt("localMinute"),
                0,
            )
            set(Calendar.MILLISECOND, 0)
        }
        if (recurrence == "none") {
            val isAfterReference = if (includeCurrent) {
                candidate.timeInMillis >= afterMillis
            } else {
                candidate.timeInMillis > afterMillis
            }
            return candidate.timeInMillis.takeIf { isAfterReference }
        }

        val days = data.optJSONArray("daysOfWeek") ?: JSONArray()
        if (recurrence == "customDays" && days.length() == 0) return null

        repeat(370) {
            val weekday = ((candidate.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1
            val matchesRule = when (recurrence) {
                "daily", "weekly" -> true
                "weekdays" -> weekday in 1..5
                "customDays" -> (0 until days.length()).any {
                    days.optInt(it) == weekday
                }
                else -> false
            }
            val isAfterReference = if (includeCurrent) {
                candidate.timeInMillis >= afterMillis
            } else {
                candidate.timeInMillis > afterMillis
            }
            if (isAfterReference && matchesRule) {
                data.put("localYear", candidate.get(Calendar.YEAR))
                data.put("localMonth", candidate.get(Calendar.MONTH) + 1)
                data.put("localDay", candidate.get(Calendar.DAY_OF_MONTH))
                data.put("localHour", candidate.get(Calendar.HOUR_OF_DAY))
                data.put("localMinute", candidate.get(Calendar.MINUTE))
                return candidate.timeInMillis
            }
            candidate.add(
                Calendar.DAY_OF_YEAR,
                if (recurrence == "weekly") 7 else 1,
            )
        }
        return null
    }

    private fun alarmAction(id: String) = "com.lujayn.REMINDER_ALARM.$id"

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
}
