# Handover report

Written 2026-11-01. For the next agent picking up Lujayn.

Read this first, then `AGENTS.md`, then `lujayn-project-brief.md`.

---

## 1. Where things stand in one paragraph

PR #21 (reminder form redesign) is **merged to `main`**. PR #22 (Android alarm
delivery + call-style alert + the new logo) is **open as a draft, pushed, and
waiting on one unverified CI run**. There is **uncommitted work in the working
tree right now** (a real bug fix — see §4). Nothing else is half-done. The
project is **not finished**: issue #5 is nearly done, #3 is partly done, and
#6, #16, #17, #18 have not been started.

---

## 2. Repository state (verified locally)

```
branch : feat/android-reminder-scheduling
HEAD   : 9e6e5ae  docs(android): add the physical-device reminder delivery test matrix
origin : 9e6e5ae  (in sync — everything is pushed)
main   : 8197cf4  feat(ui): redesign reminder creation and editing (#21)
```

Branch commits on top of `main`:

```
9e6e5ae docs(android): add the physical-device reminder delivery test matrix
d529f6b feat(brand): adopt the Lujayn bell logo across the app
03d1031 feat(reminders): present due reminders as a call-style alert
b597b94 fix(android): repair alarm bridge imports and harden delivery
a384d9a ci: include alarm action tests in formatter diagnostics
891b5eb test(reminders): verify alarm sync for reminder actions
... (plus the earlier alarm-engine commits)
```

**Uncommitted:**

```
 M analysis_options.yaml                       <- auto-churn, revert, never commit
?? Smart Bell Reminder Icon-1.png              <- user's file, leave it alone
```

Toolchain: Flutter 3.47.9 / Dart 3.13.7 (stable). CI uses `stable` too.

---

## 3. What is done and verified

Every item below was checked with the real toolchain, not assumed.

- **`dart format --output=none --set-exit-if-changed lib test`** — clean.
- **`flutter analyze --fatal-infos`** — no issues.
- **`flutter test`** — 42 passing at commit `9e6e5ae` (39 before the call-host
  tests were added).
- **CI run 41285344944** — succeeded, 5m38s. That run executes
  `dart run build_runner build`, format, analyze, `flutter test`, and
  `flutter build apk --debug`, so the Kotlin and the icon resources compiled.
  It predates `03d1031`/`d529f6b`/`9e6e5ae`, so those three still need a green
  run before merge.

### PR #21 — merged (`8197cf4`)

Root cause of the "form is zero height" bug: `Center` (and `ResponsiveCenter`)
inside Scaffold's `bottomNavigationBar` slot receives unbounded height, so the
bar became infinitely tall and squeezed the body to zero. Fixed with
`Center(heightFactor: 1)` and `body: Form > ResponsiveCenter > ListView`.

### PR #22 — open, draft

**Alarm engine (Kotlin + Dart)**

- `ReminderAlarmScheduler.kt` — AlarmManager, stable per-reminder
  PendingIntents, persisted alarm metadata in SharedPreferences, recovery after
  reboot / time change / timezone change / package replace, `notifyIfMissed`.
- `ReminderAlarmReceiver.kt` — posts the notification, requests a full-screen
  intent only when allowed, re-arms the next occurrence.
- `ReminderRescheduleReceiver.kt` — boot / `TIME_SET` / `TIMEZONE_CHANGED` /
  `MY_PACKAGE_REPLACED` / `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED`.
- `reminder_schedule_planner.dart` — pure Dart planner choosing the next
  eligible occurrence. `recurrence_rule.dart` has a DST-safe `_addDays`.

**Call-style alert**

- `reminder_call_bridge.dart` (domain contract),
  `android_reminder_call_bridge.dart` (MethodChannel
  `com.lujayn/reminder_alarms` + EventChannel `com.lujayn/reminder_call_events`),
  `noop_reminder_call_bridge.dart`.
- `reminder_call_screen.dart` — the surface: reminder label, time, caller badge
  with initials, title, note, recurrence summary, `Done`, `Snooze 10 minutes`,
  and an honest note that Android may show a notification instead.
- `app.dart` is now `ConsumerStatefulWidget` with a `navigatorKey`. It pushes
  the call screen for both the launch request and live events.
- `snooze` and `dismissOccurrence` on `ReminderActionNotifier`:
  - snooze schedules a **separate one-off alarm** with id `<id>::snooze`, so a
    recurring series never shifts its anchor time;
  - dismiss completes a one-time reminder, and for a recurring one it just
    re-syncs the next occurrence.

**Branding (issue #3, partly)**

- `Lujayn-logo.png` is the source of truth.
- Generated: legacy launcher PNGs (5 densities), adaptive
  `ic_launcher_foreground.png` (5 densities) + `mipmap-anydpi-v26/ic_launcher.xml`
  + `values/colors.xml`, notification `drawable-*/ic_stat_lujayn.png`, web
  icons + favicon, `assets/images/lujayn_mark.png`.
- `LujaynMark` widget in `lib/core/widgets/`, shown in the home header and the
  Settings app bar, tinted with `colorScheme` tokens.
- Fixed the lowercase `android:label="lujayn"` and the leftover Flutter defaults
  in `web/manifest.json` and `web/index.html`.

**Docs**

- `docs/android-device-test-matrix.md` — what each OS layer can refuse and the
  checklist to run on real hardware. **None of it has been run yet.**

---

## 4. A bug that was found and fixed — understand it before you touch this code

**The bug.** A snooze alarm carries the id `<reminderId>::snooze`. When that
alarm fired, Android handed that id back to Dart, and the call screen looked up
`<reminderId>::snooze` in the reminder store, found nothing, and showed
"Reminder not found". Snoozing would have broken the alert ten minutes later.

**The fix (committed as `8ef8816`).**

- `lib/features/reminders/domain/models/reminder_alarm_id.dart`:
  `snoozeAlarmId(id)` and `reminderIdFromAlarmId(alarmId)`.
- `android_reminder_call_bridge.dart` `_parse` calls `reminderIdFromAlarmId(id)`,
  so both the launch path and the live-event path are covered.
- `reminder_providers.dart` uses the shared `snoozeAlarmId` instead of its own
  private `_snoozeAlarmId`.
- `test/reminder_alarm_id_test.dart` covers the round trip and the `::snooze`
  edge cases.

**The lesson, because it generalises:** whenever the platform can hand back an
id, make sure the id it hands back is one the reminder store actually knows.
Keep that mapping in one place — the controller and the bridge drifting apart is
exactly how this happened.

Verified after the fix: format clean, `flutter analyze --fatal-infos` clean,
**45 tests passing**.

---

## 5. Then, in order

0. **Push `8ef8816` and `docs/HANDOVER.md` first.** They were committed locally
   while the network was unreliable, so check `git status` and
   `git log origin/feat/android-reminder-scheduling --oneline -1` before
   assuming the remote is current.
1. **Confirm CI is green on the final push.** The run must show the
   `Build Android debug APK` step passing. Only then is the Kotlin proven.
   `gh run list --branch feat/android-reminder-scheduling --limit 1`
2. **Mark PR #22 ready and merge it** (`gh pr ready 22`, then
   `gh pr merge 22 --squash --delete-branch`). Do not merge on a red or unknown
   run.
3. **Physical-device verification.** Fill in
   `docs/android-device-test-matrix.md` on real hardware and paste the result
   into the PR. Nothing in the alarm path may be called "working" until this is
   done.
4. **Then the remaining issues**, roughly in this order:
   - **#5** — close out the alarm engine once the matrix is filled.
   - **#6** — local voice recording, playback, TTS, reminder sounds. No network,
     no cloud transcription.
   - **#3** — finish the visual identity: the logo is in, but the design
     direction work is not.
   - **#16** — encrypted local backup and restore (local file, user-held key).
   - **#17** — on-device natural-language reminder creation. Must stay on-device.
   - **#18** — iOS support via native notifications. Only after Android is
     settled.

---

## 6. Environment traps that will waste your time

These are real, hit repeatedly in this session. Read them.

### Flutter commands deadlock if run concurrently

Two `flutter` invocations at once both end up in `futex_do_wait` and hang
forever. **Never run two at the same time.** If it happens:

```bash
pkill -9 -f flutter_tools.snapshot
rm -f /home/adam/flutter/bin/cache/lockfile
```

Then run one command at a time, sequentially.

### `tail` hides background output

`flutter build apk 2>&1 | tail -25` shows nothing until the pipe closes, so a
backgrounded build looks dead when it is fine. Redirect to a file instead:
`flutter build apk --debug > /tmp/opencode/apk.log 2>&1`.

### The local APK build cannot succeed here

`flutter build apk --debug` fails locally with:

```
Could not download armeabi_v7a_debug-1.0.0-89c39edfdfae...jar
Could not get resource 'https://storage.googleapis.com/download.flutter.io/...'
```

That is the network, not the code. The Gradle cache is missing the engine jars
for this exact Flutter revision and `storage.googleapis.com` is unreachable or
timed out from this machine. **Do not chase this.** Use CI as the Android build
gate; the workflow runs `flutter build apk --debug`.

### `analysis_options.yaml` rewrites itself

`flutter analyze` appends an `analyzer.exclude` block for build/platform
directories. Always `git checkout analysis_options.yaml` before committing.
Never commit that change.

### Other local churn to revert, never commit

- `linux/flutter/generated_plugins.cmake`
- `.metadata`

### Flutter SDK re-download loop

`bin/cache/dart-sdk.stamp` must contain
`89c39edfdfae2949f6806e4a315c0c08522238b7`, or Flutter re-downloads the SDK and
hangs. It is correct right now.

### Widget tests default to Android

`defaultTargetPlatform` is `TargetPlatform.android` in tests, so
`reminderAlarmSchedulerProvider` and `reminderCallBridgeProvider` resolve to the
Android implementations. Any widget test that pumps the app must override
`reminderAlarmSchedulerProvider`, and should override
`reminderCallBridgeProvider` with a fake. See
`test/app_reminder_call_host_test.dart` for a working example.

### CI needs generated Drift code

The workflow runs `dart run build_runner build` before format/analyze/test.
`lib/core/database/app_database.g.dart` is committed, but regenerate it if you
touch the Drift schema.

---

## 7. Product rules you must not break

From `AGENTS.md` and the brief. These are not negotiable and not up for
interpretation:

- Reminder content, recordings and preferences stay **on-device**.
- **No** accounts, backend, analytics, ads, cloud sync, or network dependency.
- **No** contacts, call-log, SMS, or unrelated permissions.
- **Never** claim an alarm or full-screen reminder is guaranteed on every
  Android device. Document OS and OEM restrictions instead.
- Domain logic stays independent of Flutter widgets, storage and Android APIs.
- A missed reminder is a **reliability bug**, not a cosmetic issue.
- Keep it understandable for someone who is not technically confident.

---

## 8. Quality gate before any PR

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
```

Run them **one after another**, not in parallel. State clearly if a command
could not be run. Do not claim a physical-device check that was not performed.

---

## 9. UI work

Read `.agents/skills/lujayn-mobile-design/SKILL.md` and
`docs/design-direction.md` before changing any screen. Every screen must work
across all five themes, handle its loading/empty/error states, survive text
scaling, and use semantic theme tokens — no hardcoded colours.

The logo is a **white silhouette on a transparent canvas** in
`assets/images/lujayn_mark.png`, so `LujaynMark` tints it with a theme token.
The Android launcher artwork is the dark bell flattened onto a white tile; the
adaptive foreground is transparent; the notification icon is a white
silhouette Android tints itself. Regenerate from the source's **alpha channel**
(`magick Lujayn-logo.png -alpha extract`), not from a white-background cutout —
a naive `-trim`/`-negate` approach inverts the mask and produces a bell-shaped
hole. That mistake was made and fixed once already.

---

## 10. Open decisions recorded

- Snooze is a separate one-off alarm, never a mutation of the reminder's own
  scheduled time. A recurring series must keep its anchor.
- Dismiss completes a one-time reminder; a recurring reminder stays active and
  only re-syncs the next alarm.
- Permission dialogs never block saving a reminder. Inexact delivery is the
  documented fallback.
- The launch hand-off is retried after the first frame, because the navigator
  does not exist when `initState` runs. Without that retry the alert is silently
  dropped on a cold start.
- The call screen keeps initials as its "caller" badge rather than the logo, so
  the user can tell reminders apart at a glance.

---

## 11. Loose ends

- `Smart Bell Reminder Icon-1.png` sits untracked in the repo root. It is the
  user's file, not generated here. Ask before deleting or committing it.
- PR #22's body was rewritten to describe the call surface, the branding and the
  honest limitations. Keep it accurate if you add to it.
- The logo is not yet in `web/index.html` as a favicon beyond
  `web/favicon.png`; that is already wired.
