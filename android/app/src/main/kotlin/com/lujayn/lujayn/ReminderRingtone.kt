package com.lujayn.lujayn

import android.content.Context
import android.content.SharedPreferences
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore

/**
 * Remembers the chosen ringtone and any reminder declined from a notification.
 *
 * This is deliberately SharedPreferences rather than the Flutter database: the
 * ringing service must read it while the Flutter engine is asleep or not
 * running at all.
 */
internal object ReminderRingtoneStore {
    private const val PREFS = "lujayn_ringtone"
    private const val KEY_SELECTED_URI = "selected_uri"
    private const val KEY_RINGING_ID = "ringing_id"
    private const val KEY_DECLINED_IDS = "declined_ids"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** The saved tone, or the phone's default ringtone when none is saved. */
    fun ringtoneUri(context: Context): Uri? {
        val saved = prefs(context).getString(KEY_SELECTED_URI, null)
        if (!saved.isNullOrEmpty()) {
            val uri = Uri.parse(saved)
            if (uri.toString().isNotEmpty()) return uri
        }
        return defaultRingtoneUri(context)
    }

    fun selectedId(context: Context): String? =
        prefs(context).getString(KEY_SELECTED_URI, null)

    fun setSelected(context: Context, id: String?) {
        val editor = prefs(context).edit()
        if (id.isNullOrEmpty() || id == "default") {
            editor.remove(KEY_SELECTED_URI)
        } else {
            editor.putString(KEY_SELECTED_URI, id)
        }
        editor.apply()
    }

    fun setRingingId(context: Context, id: String?) {
        val editor = prefs(context).edit()
        if (id == null) editor.remove(KEY_RINGING_ID) else editor.putString(KEY_RINGING_ID, id)
        editor.apply()
    }

    fun ringingId(context: Context): String? =
        prefs(context).getString(KEY_RINGING_ID, null)

    fun addDeclined(context: Context, reminderId: String) {
        val current = prefs(context).getStringSet(KEY_DECLINED_IDS, emptySet()) ?: emptySet()
        prefs(context).edit()
            .putStringSet(KEY_DECLINED_IDS, current + reminderId)
            .apply()
    }

    /** Reads and clears the declined ids so each is handled exactly once. */
    fun takeDeclined(context: Context): List<String> {
        val current = prefs(context).getStringSet(KEY_DECLINED_IDS, emptySet())
            ?.toList() ?: emptyList()
        if (current.isNotEmpty()) {
            prefs(context).edit().remove(KEY_DECLINED_IDS).apply()
        }
        return current
    }

    /** The phone's default ringtone, falling back to alarm then notification. */
    fun defaultRingtoneUri(context: Context): Uri? {
        return RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
    }

    /** Every ringtone Android exposes, with the current default marked. */
    fun list(context: Context): List<Map<String, Any>> {
        val defaultUri = defaultRingtoneUri(context)
        val manager = RingtoneManager(context).apply {
            setType(RingtoneManager.TYPE_RINGTONE)
        }
        val cursor = try {
            manager.cursor
        } catch (_: Exception) {
            null
        } ?: return emptyList()

        val result = mutableListOf<Map<String, Any>>()
        try {
            val titleIndex = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
            while (cursor.moveToNext()) {
                val uri = manager.getRingtoneUri(cursor.position) ?: continue
                val title = if (titleIndex >= 0) {
                    cursor.getString(titleIndex)
                } else {
                    null
                } ?: "Ringtone"
                result.add(
                    mapOf(
                        "id" to uri.toString(),
                        "title" to title,
                        "isDefault" to (uri == defaultUri),
                    ),
                )
            }
        } finally {
            cursor.close()
        }
        return result
    }

    fun supportsRingtones(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT
}
