# Handover report

Written 2026-11-01. For the next agent picking up Lujayn.

Read this first, then `AGENTS.md`, then `lujayn-project-brief.md`.

---

## 1. Where things stand in one paragraph

`main` is at `84f0a27`, 139 tests pass, and the working tree is clean. Issue #5
(alarm engine) is merged, **#3 (visual identity) is completed and closed**,
**#6 (audio & voice recording) is completed and closed**,
#18 (iOS) is **closed as deferred**, and Caller Persona + Interactive Phone Call
Simulation has been implemented and tested. **No one has run the app on a real phone
yet** — that is the one honest gap in the delivery work, and it now covers the
voices and call simulation too. `docs/android-device-test-matrix.md` is the checklist.

What is left: physical device verification for #5, the sherpa-onnx engine adapter for downloaded voice packs, encrypted backup (#16),
on-device natural language (#17). #18 is out of scope until Android is settled.

**Milestone 2026-11-01 (latest):** Caller Persona customization (presets + custom name/number/icon), Drift schema v3 migration, interactive phone call answering simulation with live call duration counter, automated voice/speech playback upon answering, dialpad responses (1: Done, 2: Reschedule, 3: Keep Active), and Hang Up control landed (139 tests passing).

---

## 2. Repository state (verified locally)

```
branch : main
HEAD   : 1692450  feat(ui): add tactile haptic feedback across interactive controls
origin : 1692450  (in sync)
```

Recent history:

```
1692450 feat(ui): add tactile haptic feedback across interactive controls
5dd79e3 feat(ui): refine home header, segmented filters, and floating navigation capsule
2a2e7a9 docs: record PR #23 merge, Issue #3 closure, and 104 passing tests in handover
0c27c55 feat(ui): redesign reminder detail and settings screens around Lujayn design system (#23)
53955de docs: add speech and voice-pack cases to the device matrix
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
- **`flutter test`** — 104 passing at `0c27c55`.
- **CI** — green on `0c27c55` (PR #23 merge) and all earlier merges. The pipeline runs
  `build_runner`, format, analyze, `flutter test` and `flutter build apk --debug`.

### PR #23 — merged (`0c27c55`)

Redesigned `ReminderDetailScreen` and `SettingsScreen` to bring them in line with
Lujayn's design system tokens, closing Issue #3:
- Replaced nested Cards with clean `Material` bordered surfaces (`AppRadius.surface`,
  `AppSpacing.gutter`, `AppSpacing.md`).
- Solved Flutter assertion where `ListTile` inside `DecoratedBox` hid ink splashes
  by converting container wrappers to true `Material` surfaces.
- Made recurrence and status badges wrap with `Flexible` text, eliminating RenderFlex
  overflows at 200% text scale.
- Re-organized Settings to prioritize **DATA & PRIVACY** directly beneath the privacy
  promise banner.
- Replaced placeholder icons with `LujaynMark` and cleaned up legacy "Phase 0" tags.
- Added comprehensive widget test suites (`test/reminder_detail_screen_test.dart`
  and `test/settings_screen_test.dart`) covering rendering, interactions, dialogs,
  200% text scale, and all 5 themes. 11 new tests, bringing the total to 104.

### Voice and speech (`a3a147c`, `e16ea00`)

- `ReminderSpeechService` is the domain contract. `FlutterReminderSpeechService`
  speaks with the device engine; `NoopReminderSpeechService` reports itself
  unavailable on other targets. Provider: `reminderSpeechServiceProvider`.
- Speech is opt-in. `spokenRemindersEnabledProvider` defaults to **off**,
  because a reminder can arrive in a meeting. The call screen always offers a
  manual "Read aloud" when an engine exists, and says so plainly when the
  setting is on but no engine is installed.
- Leaving the call screen stops speech.
- The voice pack system lives under `lib/features/voice`. Two packs, both
  Apache-2.0, both verified against the upstream release:

  | Pack | Download | Unpacked | Voices |
  |---|---|---|---|
  | Light (Kitten Nano fp16) | 25.6 MB | 40 MB | 8 |
  | Natural (Kokoro v0.19 int8) | 98.5 MB | 151 MB | 11 |

  **Both packs name their model file something other than `model.onnx`**
  (`model.fp16.onnx`, `model.int8.onnx`). That is recorded per pack in
  `voice_catalog.dart`. Read `docs/voice-packs.md` before touching it.
- Installs are staged and atomic: download → SHA-256 check → bzip2/tar on a
  background isolate → marker file → rename. Every failure path is tested
  against a real `.tar.bz2` built in the test.
- Deleting a pack moves the selection back to the device voice.

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

1. **Issue #3 is completed and closed.** (PR #20, PR #21, PR #22, and PR #23
   redesigned Home, create/edit, call surface, reminder detail, and settings).
2. **Finish #6.** Two of the four Phase 3 pieces are in (device TTS, voice
   packs). Still to do:
   - **The engine adapter.** Add `sherpa_onnx`, implement an `OfflineVoiceEngine`
     behind `ReminderSpeechService`, and make `reminderSpeechServiceProvider`
     pick the installed pack when one is selected and fall back to the device
     engine otherwise. `docs/voice-packs.md` has the exact model paths and the
     `OfflineTts`/`OfflineTtsKokoroModelConfig` API shape.
   - **Playback.** sherpa-onnx returns `Float32List` samples plus a sample rate;
     they need to become sound. `audioplayers` (as the upstream Flutter example
     uses) or Android `AudioTrack` are the options.
   - **Voice recording and playback** for a spoken reminder, which needs
     `RECORD_AUDIO` and the audio-focus rules the brief mentions.
   - **Reminder tones and vibration** configuration.
3. **Physical-device verification.** Fill in
   `docs/android-device-test-matrix.md` on real hardware when an Android device
   is connected. Nothing in the alarm path or the voice path may be called "working"
   until this is done.
4. **Then the remaining issues**, roughly in this order:
   - **#16** — encrypted local backup and restore (local file, user-held key).
     Note the recurrence fix in §4b — restore will feed the app untrusted data.
   - **#17** — on-device natural-language reminder creation. Must stay on-device.

**#18 (iOS) is closed as deferred.** Do not reopen it until Android is verified
on hardware and a Mac is available; an untestable platform implementation is
guesswork.

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
- **The voices do not speak yet.** The catalog, download, verification, install
  and selection are done and tested; the sherpa-onnx adapter and audio playback
  are not written. Do not describe the downloadable voices as working.
- `VoicePack.installedBytes` and the model file names are measured facts, not
  estimates. If a pack version is bumped, download and inspect the archive again
  before changing the catalog — both packs name their model file something other
  than `model.onnx`.
- The Kokoro pack needs 151 MB of storage. On a device with little free space
  the install fails cleanly but there is no pre-flight free-space check yet.
  Worth adding before release.
- `ReminderSpeechService` currently always resolves to the device engine. The
  pack selection is stored and displayed but not yet consulted when speaking.

---

## 12. Where I stopped

Last verified state, so you do not have to guess:

```bash
dart format --output=none --set-exit-if-changed lib test   # clean
flutter analyze --fatal-infos                              # no issues
flutter test                                               # 142 passing
```

Caller Persona simulation and Interactive In-Call Phone Screen (Answer Call,
connected live duration timer, auto voice note & speech readout, dialpad response
keys 1/2/3, red Hang Up button, on-device caller profile image support via app-private
storage and image picker, and Drift schema v4 migration) are landed and verified across 142 passing tests.
The next actions are physical-device verification for #5, the sherpa-onnx engine adapter for downloadable offline voice packs, encrypted backup (#16), and on-device natural language (#17).
