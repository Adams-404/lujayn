package com.lujayn.lujayn

import android.app.AlarmManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val alarmChannelName = "com.lujayn/reminder_alarms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        ReminderNotifications.createChannel(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            alarmChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canScheduleExactAlarms" -> {
                    result.success(ReminderAlarmScheduler.canScheduleExactAlarms(this))
                }

                "requestExactAlarmPermission" -> {
                    if (ReminderAlarmScheduler.canScheduleExactAlarms(this)) {
                        result.success(true)
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                            Uri.parse("package:$packageName"),
                        )
                        startActivity(intent)
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }

                "schedule" -> {
                    val id = call.argument<String>("id")
                    val title = call.argument<String>("title")
                    val description = call.argument<String>("description")
                    val scheduledAtMillis = call.argument<Number>("scheduledAtMillis")
                    val recurrenceType = call.argument<String>("recurrenceType") ?: "none"
                    val daysOfWeek = call.argument<List<Int>>("daysOfWeek") ?: emptyList()
                    val localYear = call.argument<Int>("localYear")
                    val localMonth = call.argument<Int>("localMonth")
                    val localDay = call.argument<Int>("localDay")
                    val localHour = call.argument<Int>("localHour")
                    val localMinute = call.argument<Int>("localMinute")
                    if (
                        id == null || title == null || scheduledAtMillis == null ||
                        localYear == null || localMonth == null || localDay == null ||
                        localHour == null || localMinute == null
                    ) {
                        result.error("INVALID_ARGUMENTS", "Missing reminder alarm data.", null)
                    } else {
                        ReminderAlarmScheduler.schedule(
                            this,
                            id,
                            title,
                            description,
                            scheduledAtMillis.toLong(),
                            recurrenceType,
                            daysOfWeek,
                            localYear,
                            localMonth,
                            localDay,
                            localHour,
                            localMinute,
                        )
                        result.success(null)
                    }
                }

                "cancel" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("INVALID_ARGUMENTS", "Missing reminder ID.", null)
                    } else {
                        ReminderAlarmScheduler.cancel(this, id)
                        result.success(null)
                    }
                }

                "cancelAll" -> {
                    ReminderAlarmScheduler.cancelAll(this)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
