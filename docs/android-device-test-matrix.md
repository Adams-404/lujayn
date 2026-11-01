# Android reminder delivery: physical-device test matrix

Lujayn cannot guarantee an alarm or a full-screen reminder on every Android
device. The operating system, the OEM power manager, and the user's battery and
notification settings all sit between the app and the user.

This matrix is the checklist to run on real hardware before a release. A passing
run on an emulator does not count for any row.

## Why the fallbacks exist

| Layer | What can be refused | What Lujayn does instead |
| --- | --- | --- |
| `SCHEDULE_EXACT_ALARM` | Android 12+ may deny exact alarms | Falls back to an inexact alarm and says so in the form |
| `POST_NOTIFICATIONS` | Android 13+ may deny notifications | Reminder is saved and scheduled; the alert may not appear |
| `USE_FULL_SCREEN_INTENT` | Android 14+ may deny the full-screen grant | Shows a high-importance heads-up notification the user can tap |
| OEM battery optimisation | The process may be killed before the alarm fires | Nothing in-app can force it; the missed-reminder check on next launch reports it |
| Reboot | Pending alarms are cleared by the OS | `ReminderRescheduleReceiver` re-registers them on boot, time change and package replace |

## Devices

Record the real device and OS version used for each row. Cover at least one
device from a strict-battery OEM family (Xiaomi/Redmi, Oppo/Realme, Vivo,
OnePlus, Samsung) in addition to a stock Android device.

| # | Device | OEM skin | Android version | Exact alarms | Notifications | Full-screen intent |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | | | | granted / denied | granted / denied | granted / denied |
| 2 | | | | | | |
| 3 | | | | | | |

## Cases

Mark each cell `pass`, `fail`, or `not run`. A `fail` needs a note describing
what the user saw.

### 1. Delivery

| Case | Device 1 | Device 2 | Device 3 |
| --- | --- | --- | --- |
| One-time reminder fires while the app is open | | | |
| One-time reminder fires while the app is backgrounded | | | |
| One-time reminder fires while the screen is locked | | | |
| One-time reminder fires while the app is force-stopped | | | |
| Full-screen intent is shown when the grant is allowed | | | |
| Heads-up notification is shown when the grant is denied | | | |
| Tapping the notification opens the call-style alert | | | |

### 2. Actions

| Case | Device 1 | Device 2 | Device 3 |
| --- | --- | --- | --- |
| `Done` on a one-time reminder marks it completed | | | |
| `Done` on a recurring reminder keeps the series active | | | |
| `Snooze` re-alerts after the snooze length | | | |
| `Snooze` does not move a recurring reminder's original time | | | |
| Back closes the alert without dismissing the reminder | | | |

### 3. Recovery

| Case | Device 1 | Device 2 | Device 3 |
| --- | --- | --- | --- |
| Reboot reschedules future reminders | | | |
| Changing the system timezone keeps the chosen wall-clock time | | | |
| Changing the system time re-schedules pending alarms | | | |
| Updating the app re-registers alarms (`MY_PACKAGE_REPLACED`) | | | |
| A reminder missed while the app was closed is reported on next launch | | | |

### 4. Permission flows

| Case | Device 1 | Device 2 | Device 3 |
| --- | --- | --- | --- |
| Denying notifications still saves and schedules the reminder | | | |
| Denying exact alarms still saves the reminder with an inexact alarm | | | |
| Denying the full-screen grant still delivers a heads-up notification | | | |
| Granting exact alarms from Settings re-schedules pending reminders | | | |

### 5. Interface

| Case | Device 1 | Device 2 | Device 3 |
| --- | --- | --- | --- |
| Call-style alert is usable at 200% font scale | | | |
| Call-style alert is usable in all five themes | | | |
| Launcher icon renders on the home screen and in the app switcher | | | |
| Notification small icon renders (not a white square) | | | |
| Adaptive icon is not cropped on the launcher | | | |

## Reporting

Copy this file into the pull request description, fill in the devices and
results, and note anything that failed. Do not describe a case as passing
unless it was run on the device listed in that column.
