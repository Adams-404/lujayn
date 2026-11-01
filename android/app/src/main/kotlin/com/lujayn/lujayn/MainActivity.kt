package com.lujayn.lujayn

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val alarmChannelName = "com.lujayn/reminder_alarms"
    private val callEventChannelName = "com.lujayn/reminder_call_events"

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 4301
    }

    private var notificationPermissionResult: MethodChannel.Result? = null
    private var callEventSink: EventChannel.EventSink? = null
    private var pendingReminderCall: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        pendingReminderCall = reminderCallFrom(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val request = reminderCallFrom(intent) ?: return
        val sink = callEventSink
        if (sink == null) {
            // Flutter is not attached yet; hand it over on the next read.
            pendingReminderCall = request
        } else {
            sink.success(request)
        }
    }

    override fun onDestroy() {
        notificationPermissionResult = null
        callEventSink = null
        super.onDestroy()
    }

    private fun reminderCallFrom(intent: Intent?): Map<String, Any?>? {
        val id = intent?.getStringExtra(ReminderAlarmReceiver.EXTRA_ID) ?: return null
        if (id.isEmpty()) return null
        return mapOf(
            "id" to id,
            "title" to intent.getStringExtra(ReminderAlarmReceiver.EXTRA_TITLE),
            "description" to intent.getStringExtra(ReminderAlarmReceiver.EXTRA_DESCRIPTION),
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            notificationPermissionResult?.success(granted)
            notificationPermissionResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        ReminderNotifications.createChannel(this)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            callEventChannelName,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    callEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    callEventSink = null
                }
            },
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            alarmChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "takePendingReminderCall" -> {
                    val pending = pendingReminderCall
                    pendingReminderCall = null
                    result.success(pending)
                }
                "canScheduleExactAlarms" -> {
                    result.success(ReminderAlarmScheduler.canScheduleExactAlarms(this))
                }

                "canPostNotifications" -> {
                    val enabled = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
                        true
                    } else {
                        getSystemService(NotificationManager::class.java)
                            .areNotificationsEnabled()
                    }
                    result.success(enabled)
                }

                "requestNotificationPermission" -> {
                    if (
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                            PackageManager.PERMISSION_GRANTED
                    ) {
                        notificationPermissionResult = result
                        requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            NOTIFICATION_PERMISSION_REQUEST,
                        )
                    } else {
                        result.success(true)
                    }
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
