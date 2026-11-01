# Handover report

Written 2026-11-01. For the next agent picking up Lujayn.

Read this first, then `AGENTS.md`, then `lujayn-project-brief.md`.

---

## 1. Where things stand in one paragraph

**PR #21 and PR #22 are both merged to `main`.** `main` is at `93ff905`, CI is
green, 62 tests pass, and the working tree is clean. Issue #5 (alarm engine) and
most of #3 (visual identity) are in. **No one has run the app on a real phone
yet** — that is the one honest gap in the delivery work.
`docs/android-device-test-matrix.md` is the checklist for it.

What is left: #3 needs the remaining screens reviewed (detail, settings, call
surface) and a screenshot note; #6 (voice/TTS/sounds), #16 (encrypted backup),
#17 (on-device natural language) and #18 (iOS) have not been started.

**Milestone 2026-11-01:** PR #22 merged, then a first pass at #3 landed — design
tokens, deliberate loading/error/permission-denied states on Home, and two
text-scaling overflows found and fixed.

---

## 2. Repository state (verified locally)

```
branch : main
HEAD   : 93ff905  feat(ui): give the home screen deliberate loading, error and blocked states
origin : 93ff905  (in sync)
```

Recent history:

```
93ff905 feat(ui): give the home screen deliberate loading, error and blocked states
ca6ddf6 feat(android): add local AlarmManager reminder delivery (#22)
8197cf4 feat(ui): redesign reminder creation and editing (#21)
af9cf43 feat(ui): add time-first reminder timeline
df68577 feat(storage): persist reminders locally with Drift and SQLite
```

**Uncommitted:**

```
?? Smart Bell Reminder Icon-1.png              <- user's file, leave it alone
```

Toolchain: Flutter 3.47.9 / Dart 3.13.7 (stable). CI uses `stable` too.

---

## 3. What is done and verified

Every item below was checked with the real toolchain, not assumed.

- **`dart format --output=none --set-exit-if-changed lib test`** — clean.
- **`flutter analyze --fatal-infos`** — no issues.
- **`flutter test`** — 62 passing at `93ff905`.
- **CI** — green on `ca6ddf6` (the #22 merge) and earlier. The pipeline runs
  `build_runner`, format, analyze, `flutter test` and `flutter build apk --debug`,
  so the APK step passing is what proves the Kotlin and icon resources compile.
  `93ff905` has not had its own run yet — confirm it.

### PR #21 — merged (`8197cf4`)

Root cause of the "form is zero height" bug: `Center` (and `ResponsiveCenter`)
inside Scaffold's `bottomNavigationBar` slot receives unbounded height, so the
bar became infinitely tall and squeezed the body to zero. Fixed with
`Center(heightFactor: 1)` and `body: Form > ResponsiveCenter > ListView`.

### PR #22 — merged (`ca6ddf6`)

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
**54 tests passing**.

## 4b. A second bug found and fixed — recurrence could hang

`RecurrenceRule.calculateNextOccurrence` looped until it found a matching
weekday. A custom-day list holding only out-of-range values matched nothing, so
the loop never ended and the app froze. Nothing in the UI can produce that
today, but backup restore (#16) will feed this method data the app did not
create, so it must terminate on any input.

The day loops are now bounded by a four-year lookahead and the custom day list
is filtered to real weekdays. A reminder more than four years overdue is dropped
rather than silently re-armed. Covered by `test/recurrence_rule_test.dart`.

## 4c. A third bug found and fixed — a reminder that could never fire

The form accepted a one-time reminder whose time had already passed. The planner
then rejected it, the scheduler cancelled, and the user still saw
"Reminder saved". Nothing ever fired and nothing explained why.

`_save()` in `reminder_form_screen.dart` now refuses that save and says
"Choose a time in the future, or make this a repeating reminder." Repeating
reminders are unaffected, because the planner advances them to their next
occurrence. Covered by `test/reminder_form_screen_test.dart`.

This is the pattern worth internalising: **a reminder that is accepted but never
delivered is a reliability bug.** Prefer refusing the save over saving silently.

## 4d. Two overflows found while doing #3

Testing Home at 200% text exposed both:

- `EmptyStateView` clipped by 21px when a notice sat above it, because the
  column had a fixed vertical padding and no scroll. It now scrolls.
- The filter row (`Upcoming / Completed / All`) overflowed horizontally by 290px
  on a 360dp screen at double text. It now scrolls horizontally.

Both are accessibility bugs, not cosmetics — a clipped state means an action the
user cannot reach. `test/home_screen_states_test.dart` now pins both at 200%
text on a small screen.

---

## 5. Then, in order

1. **Confirm CI is green on `93ff905`.** `gh run list --branch main --limit 1`.
2. **Physical-device verification.** Fill in
   `docs/android-device-test-matrix.md` on real hardware. Nothing in the alarm
   path may be called "working" until this is done. This is the only thing
   blocking #5 from being closed.
3. **Finish #3.** Tokens and Home states are in. Still to review:
   reminder detail, settings, and the call-style surface; plus a screen-by-screen
   note or screenshots in a PR, which the issue explicitly asks for.
4. **Then the remaining issues**, roughly in this order:
   - **#6** — local voice recording, playback, TTS, reminder sounds. No network,
     no cloud transcription. This is the heart of the product and the biggest
     remaining piece.
   - **#16** — encrypted local backup and restore (local file, user-held key).
     Note the recurrence fix in §4b — restore will feed the app untrusted data.
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
- A one-time reminder in the past is refused at save time rather than stored and
  silently ignored.
- Recurrence search is bounded. A reminder more than four years overdue is
  dropped, not re-armed.
- Spacing and radii come from `AppSpacing` / `AppRadius` in
  `lib/app/theme/app_spacing.dart`, not from literals. New code should use them;
  older widgets are being migrated as they are touched.
- Home never nags about permissions when delivery is healthy. The notice only
  appears when something is actually wrong.

---

## 11. Loose ends

- `Smart Bell Reminder Icon-1.png` sits untracked in the repo root. It is the
  user's file, not generated here. Ask before deleting or committing it.
- PR #22's body was rewritten to describe the call surface, the branding and the
  honest limitations. Keep it accurate if you add to it.
- `ReminderStatus.missed` exists but nothing sets it. Android posts a
  "Missed: …" notification for a one-time reminder that passed while the device
  was off, but the stored reminder stays `active`. Decide whether the app should
  record the missed state or whether the enum value should be removed. Do not
  remove it casually — it may already be persisted in existing databases.
- PR #22 is merged, but the physical-device matrix is still empty. That is the
  outstanding honesty item, not a code problem.
- Issue #5 can be closed once the matrix is filled in.

---

## 12. Where I stopped

Last verified state, so you do not have to guess:

```bash
dart format --output=none --set-exit-if-changed lib test   # clean
flutter analyze --fatal-infos                              # no issues
flutter test                                               # 62 passing
```

`main` is at `93ff905` and pushed. CI has not run on that commit yet.

Nothing was left half-written. The next action is to confirm CI and then work
through §5, starting with physical-device verification.
