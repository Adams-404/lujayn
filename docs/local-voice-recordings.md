# Local voice recordings: formats, storage, and platform limitations

This document describes Lujayn's local voice recording architecture, supported
audio formats, privacy protections, and platform limitations as outlined in
Issue #6.

---

## 1. Goal and principles

Lujayn allows users to attach personal, familiar voice recordings to reminders
(e.g., a family member's voice saying "Remember your morning medication").

- **Strictly on-device**: Audio never leaves the phone. No cloud sync, no
  transcription endpoints, no analytics.
- **Resilient persistence**: Only stable relative filenames are stored in the
  SQLite database, allowing the app support directory path to shift without
  broken links.
- **Accessible & graceful**: Permission denial never prevents text reminders from
  being scheduled and delivered.

---

## 2. Audio format and container

| Property | Value | Rationale |
|---|---|---|
| **Container** | MPEG-4 Audio (`.m4a`) | Standard container with native hardware support on Android and iOS. |
| **Codec** | AAC-LC (Advanced Audio Coding - Low Complexity) | Broadest hardware encoder/decoder compatibility; low CPU and battery overhead. |
| **Bitrate** | 64 kbps mono | Optimal balance between vocal clarity and minimal disk footprint (~0.5 MB per minute). |
| **Sample Rate** | 44.1 kHz | Clean vocal fidelity without unnecessary high-frequency bloat. |

---

## 3. Storage and file lifecycle

### Storage location
Recordings are saved in:
```
<getApplicationSupportDirectory()>/recordings/
```
They are explicitly **not** placed in temporary or cache directories, preventing
OS cache cleaners or OEM "storage managers" from unexpectedly wiping voice notes.

### Filename convention
Unique identifiers are generated with UUIDv4:
- `rem_<reminder_id>_<uuid>.m4a` when recorded within an existing reminder.
- `rec_<uuid>.m4a` when recorded in a new unsaved draft.

Only the relative basename (e.g. `rem_123_abc.m4a`) is stored in the `Reminders` table.
The storage layer resolves relative basenames to absolute paths at runtime via
`VoiceNoteStorageService.resolvePath()`.

### Deletion and orphan cleanup
- **Reminder deletion**: When a reminder is deleted, `ReminderActionNotifier.deleteReminder`
  triggers removal of the associated recording file from disk.
- **Reminder update / replacement**: If an existing reminder's voice note is replaced or removed,
  the previous audio file is deleted immediately.
- **Clear all**: `ReminderActionNotifier.clearAll()` wipes the entire recordings directory.
- **Orphan cleaner**: `cleanupOrphanedRecordings(List<String> activeFileNames)` scans the
  recordings folder and removes unreferenced recordings (e.g., from discarded drafts).

---

## 4. Permissions and user privacy

1. **Explicit pre-permission dialog**: Before invoking the Android system microphone
   permission prompt, Lujayn presents a clear explanation explaining why microphone
   access is requested and reaffirming that audio is kept strictly on-device.
2. **Graceful denial**: If permission is denied:
   - An informative, calm banner explains that microphone access was denied.
   - The user can continue creating, scheduling, and saving text reminders without interruption.
3. **App manifest**: Declares `android.permission.RECORD_AUDIO`. Does not request background
   microphone or call recording privileges.

---

## 5. Playback and alerts

- **Reminder Call Surface (`ReminderCallScreen`)**:
  - If a voice note is attached, `VoiceNotePlayerWidget` is displayed.
  - If "Read reminders aloud" is enabled, the recording plays automatically upon alert.
  - If no voice note is attached, the screen falls back to text-to-speech reading.
- **Reminder Details (`ReminderDetailScreen`)**:
  - Displays the audio player with duration, scrubbing slider, and play/pause controls.
- **Reminder Form (`ReminderFormScreen`)**:
  - Provides recording controls (record, timer, stop, preview player, discard/replace).

---

## 6. Platform limitations

| Limitation | Detail | Mitigation |
|---|---|---|
| **Background recording** | Not supported. Audio recording requires the user to stay on the screen while recording. | UI provides a timer and stops recording if disposed. |
| **Desktop / Linux / Web** | Recording and audio players use mobile platform plugins (`record`, `audioplayers`). | Fallback service abstractions (`NoopVoiceRecordingService`, `NoopVoicePlaybackService`, `NoopVoiceNoteStorageService`) allow tests and unsupported platforms to run seamlessly without crashes. |
| **Audio focus** | When another app (such as music or podcast) is playing, playback uses default notification/media audio focus. | Future hardware testing will tune ducking behavior. |
| **Disk space** | Voice notes are lightweight (~0.5 MB/min), but storage on ultra-low-end devices should be monitored. | Orphan cleaner ensures discarded drafts don't accumulate. |
