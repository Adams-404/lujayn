package com.lujayn.lujayn

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.ToneGenerator
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val alarmChannelName = "com.lujayn/reminder_alarms"
    private val callEventChannelName = "com.lujayn/reminder_call_events"
    private val reminderAudioChannelName = "com.lujayn/reminder_audio"
    private val reminderRingtoneChannelName = "com.lujayn/reminder_ringtone"

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 4301
    }

    private var notificationPermissionResult: MethodChannel.Result? = null
    private var callEventSink: EventChannel.EventSink? = null
    private var pendingReminderCall: Map<String, Any?>? = null
    private var reminderAudioFocusRequest: AudioFocusRequest? = null
    private var toneGenerator: ToneGenerator? = null
    private var previewPlayer: MediaPlayer? = null
    private val previewHandler = Handler(Looper.getMainLooper())
    private var previewStop: Runnable? = null

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
        resetReminderAudioRoute()
        stopRingtonePreview()
        toneGenerator?.release()
        toneGenerator = null
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

    /**
     * Routes reminder speech like a call. On Android 12+, prefer the
     * communication-device API; older versions use the legacy speaker switch.
     */
    private fun setReminderAudioRoute(useSpeaker: Boolean): Boolean {
        val audioManager = getSystemService(AudioManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            reminderAudioFocusRequest == null
        ) {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener { }
                .build()
            audioManager.requestAudioFocus(request)
            reminderAudioFocusRequest = request
        }
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val wantedType = if (useSpeaker) {
                android.media.AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
            } else {
                android.media.AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
            }
            val device = audioManager.availableCommunicationDevices
                .firstOrNull { it.type == wantedType } ?: return false
            return audioManager.setCommunicationDevice(device)
        }

        @Suppress("DEPRECATION")
        audioManager.isSpeakerphoneOn = useSpeaker
        return true
    }

    private fun resetReminderAudioRoute() {
        val audioManager = getSystemService(AudioManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.clearCommunicationDevice()
        }
        @Suppress("DEPRECATION")
        audioManager.isSpeakerphoneOn = false
        audioManager.mode = AudioManager.MODE_NORMAL
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            reminderAudioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            reminderAudioFocusRequest = null
        }
    }

    /** A short DTMF tone, so the in-call dialpad feels like a real one. */
    private fun playDialTone(key: String) {
        val tone = when (key) {
            "0" -> ToneGenerator.TONE_DTMF_0
            "1" -> ToneGenerator.TONE_DTMF_1
            "2" -> ToneGenerator.TONE_DTMF_2
            "3" -> ToneGenerator.TONE_DTMF_3
            "4" -> ToneGenerator.TONE_DTMF_4
            "5" -> ToneGenerator.TONE_DTMF_5
            "6" -> ToneGenerator.TONE_DTMF_6
            "7" -> ToneGenerator.TONE_DTMF_7
            "8" -> ToneGenerator.TONE_DTMF_8
            "9" -> ToneGenerator.TONE_DTMF_9
            "*" -> ToneGenerator.TONE_DTMF_S
            "#" -> ToneGenerator.TONE_DTMF_P
            else -> return
        }
        try {
            val generator = toneGenerator ?: ToneGenerator(AudioManager.STREAM_DTMF, 60)
                .also { toneGenerator = it }
            generator.startTone(tone, 120)
        } catch (_: Exception) {
            // A missing tone never blocks a key press.
        }
    }

    private fun previewRingtone(id: String?) {
        stopRingtonePreview()
        val uri = if (id.isNullOrEmpty() || id == "default") {
            ReminderRingtoneStore.defaultRingtoneUri(this)
        } else {
            Uri.parse(id)
        } ?: return
        try {
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            player.setDataSource(this, uri)
            player.prepare()
            player.start()
            previewPlayer = player
            val stop = Runnable { stopRingtonePreview() }
            previewStop = stop
            previewHandler.postDelayed(stop, 8_000)
        } catch (error: Exception) {
            stopRingtonePreview()
        }
    }

    private fun stopRingtonePreview() {
        previewStop?.let { previewHandler.removeCallbacks(it) }
        previewStop = null
        try {
            previewPlayer?.stop()
        } catch (_: Exception) {
        }
        previewPlayer?.release()
        previewPlayer = null
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val power = getSystemService(PowerManager::class.java)
        return power.isIgnoringBatteryOptimizations(packageName)
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
            reminderAudioChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSpeakerphone" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled == null) {
                        result.error("INVALID_ARGUMENTS", "Missing speaker state.", null)
                    } else {
                        result.success(setReminderAudioRoute(enabled))
                    }
                }
                "resetAudioRoute" -> {
                    resetReminderAudioRoute()
                    result.success(null)
                }
                "playDialTone" -> {
                    playDialTone(call.argument<String>("key") ?: "")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            reminderRingtoneChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(true)
                "startRinging" -> {
                    val id = call.argument<String>("reminderId")
                    if (id.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENTS", "Missing reminder ID.", null)
                    } else {
                        // The receiver has already started the service in the
                        // normal path. Starting again would restart the tone.
                        if (ReminderRingtoneStore.ringingId(this) == null) {
                            val info = ReminderAlarmScheduler.alarmInfo(this, id)
                            ReminderRingingService.start(
                                this,
                                id,
                                info?.first ?: "Reminder",
                                info?.second ?: "",
                            )
                        }
                        result.success(null)
                    }
                }
                "stopRinging" -> {
                    val ringingId = ReminderRingtoneStore.ringingId(this)
                    ReminderRingingService.stop(this)
                    if (ringingId != null) {
                        getSystemService(NotificationManager::class.java)
                            .cancel(ringingId.hashCode())
                    }
                    result.success(null)
                }
                "listRingtones" -> result.success(ReminderRingtoneStore.list(this))
                "getSelectedRingtone" -> result.success(ReminderRingtoneStore.selectedId(this))
                "setSelectedRingtone" -> {
                    ReminderRingtoneStore.setSelected(this, call.argument<String>("id"))
                    result.success(null)
                }
                "previewRingtone" -> {
                    previewRingtone(call.argument<String>("id"))
                    result.success(null)
                }
                "stopPreview" -> {
                    stopRingtonePreview()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

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
                "takeDeclinedReminderIds" -> {
                    result.success(ReminderRingtoneStore.takeDeclined(this))
                }
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                        )
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
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
