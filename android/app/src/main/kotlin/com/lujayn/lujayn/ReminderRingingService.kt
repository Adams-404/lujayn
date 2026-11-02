package com.lujayn.lujayn

import android.app.Notification
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Rings a due reminder like a phone call.
 *
 * A BroadcastReceiver cannot keep a ringtone looping: it returns within
 * seconds and the process may be killed. A foreground service with a partial
 * wake lock is the only shape that reliably rings on a locked phone, and it is
 * also what lets the CallStyle notification be a real incoming call.
 *
 * The service stops ringing when answered, declined, hung up, or after
 * [TIMEOUT_MS]. It never leaves a phone ringing unattended.
 */
class ReminderRingingService : Service() {
    companion object {
        private const val TAG = "LujaynRinging"
        const val ACTION_START = "com.lujayn.ringing.START"
        const val ACTION_STOP = "com.lujayn.ringing.STOP"
        const val EXTRA_ID = "reminder_id"
        const val EXTRA_TITLE = "reminder_title"
        const val EXTRA_DESCRIPTION = "reminder_description"
        const val EXTRA_CALLER_NAME = "reminder_caller_name"
        const val TIMEOUT_MS = 60_000L

        /** Starts ringing, or does nothing if this reminder is already ringing. */
        fun start(
            context: Context,
            id: String,
            title: String,
            description: String,
            callerName: String = "",
        ) {
            val intent = Intent(context, ReminderRingingService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_ID, id)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_DESCRIPTION, description)
                putExtra(EXTRA_CALLER_NAME, callerName)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (error: Exception) {
                // Android 12+ can refuse a background foreground-service start.
                // The notification still exists, so the reminder is not lost.
                Log.w(TAG, "Could not start the ringing service", error)
            }
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, ReminderRingingService::class.java))
            } catch (error: Exception) {
                Log.w(TAG, "Could not stop the ringing service", error)
            }
        }
    }

    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var focusRequest: AudioFocusRequest? = null
    private var audioManager: AudioManager? = null
    private var currentId: String? = null
    private var currentTitle: String = "Reminder"
    private var currentDescription: String = ""
    private var currentCallerName: String = ""
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { onRingTimeout() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopRinging()
            stopSelf()
            return START_NOT_STICKY
        }

        val id = intent?.getStringExtra(EXTRA_ID)
        if (id.isNullOrEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Reminder"
        val description = intent.getStringExtra(EXTRA_DESCRIPTION).orEmpty()
        val callerName = intent.getStringExtra(EXTRA_CALLER_NAME).orEmpty()

        if (currentId == id && player?.isPlaying == true) {
            return START_NOT_STICKY
        }

        stopRinging()
        currentId = id
        currentTitle = title
        currentDescription = description
        currentCallerName = callerName
        ReminderRingtoneStore.setRingingId(this, id)

        val notification = ReminderNotifications.build(this, id, title, description, callerName)
        startAsForeground(id, notification)
        startRinging()
        handler.removeCallbacks(timeout)
        handler.postDelayed(timeout, TIMEOUT_MS)

        return START_NOT_STICKY
    }

    private fun startAsForeground(id: String, notification: Notification) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    id.hashCode(),
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(id.hashCode(), notification)
            }
        } catch (error: Exception) {
            Log.w(TAG, "Could not promote the ringing service", error)
            // Without a foreground notification the service may be killed, so
            // fall back to the ordinary notification rather than crashing.
            ReminderNotifications.show(this, id, currentTitle, currentDescription)
        }
    }

    private fun startRinging() {
        acquireWakeLock()
        requestAudioFocus()
        playRingtone()
        startVibration()
    }

    private fun playRingtone() {
        val uri: Uri = ReminderRingtoneStore.ringtoneUri(this) ?: return
        try {
            val media = MediaPlayer()
            media.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            media.setDataSource(this, uri)
            media.isLooping = true
            media.prepare()
            media.start()
            player = media
        } catch (error: Exception) {
            Log.w(TAG, "Could not play the reminder ringtone", error)
            player?.release()
            player = null
        }
    }

    private fun startVibration() {
        try {
            val deviceVibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(VibratorManager::class.java).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            if (deviceVibrator == null || !deviceVibrator.hasVibrator()) return
            val pattern = longArrayOf(0, 900, 500, 900, 500, 1400, 900)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                deviceVibrator.vibrate(
                    VibrationEffect.createWaveform(pattern, 0),
                )
            } else {
                @Suppress("DEPRECATION")
                deviceVibrator.vibrate(pattern, 0)
            }
            vibrator = deviceVibrator
        } catch (error: Exception) {
            Log.w(TAG, "Could not vibrate for the reminder call", error)
        }
    }

    private fun requestAudioFocus() {
        try {
            val manager = getSystemService(AudioManager::class.java) ?: return
            audioManager = manager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val attributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(attributes)
                    .setOnAudioFocusChangeListener { }
                    .build()
                manager.requestAudioFocus(request)
                focusRequest = request
            } else {
                @Suppress("DEPRECATION")
                manager.requestAudioFocus(
                    null,
                    AudioManager.STREAM_RING,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
                )
            }
        } catch (error: Exception) {
            Log.w(TAG, "Could not take audio focus for ringing", error)
        }
    }

    private fun acquireWakeLock() {
        try {
            val power = getSystemService(PowerManager::class.java) ?: return
            val lock = power.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "Lujayn:reminder-ringing",
            )
            lock.setReferenceCounted(false)
            lock.acquire(TIMEOUT_MS + 5_000)
            wakeLock = lock
        } catch (error: Exception) {
            Log.w(TAG, "Could not hold a wake lock while ringing", error)
        }
    }

    private fun onRingTimeout() {
        val id = currentId ?: return
        // The call was never answered. Turn it into an honest missed reminder
        // instead of leaving an undismissable ongoing notification behind.
        stopRinging()
        ReminderNotifications.show(
            this,
            id,
            currentTitle,
            currentDescription,
            currentCallerName,
            missed = true,
        )
        stopSelf()
    }

    private fun stopRinging() {
        handler.removeCallbacks(timeout)
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        player?.release()
        player = null

        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        }
        vibrator = null

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
        } catch (_: Exception) {
        }
        focusRequest = null

        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null

        currentId?.let { id ->
            getSystemService(NotificationManager::class.java).cancel(id.hashCode())
        }
        ReminderRingtoneStore.setRingingId(this, null)
        currentId = null
    }

    override fun onDestroy() {
        stopRinging()
        super.onDestroy()
    }
}
