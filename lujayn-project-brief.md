# Lujayn

## Product brief and initial project specification

**Status:** Approved concept\
**Working platform:** Android first\
**Future platform:** iOS\
**Framework:** Flutter\
**Product category:** Privacy-first personal reminder companion

------------------------------------------------------------------------

## 1. What Lujayn is

Lujayn is a private, local-first reminder application built around the
idea of a simulated incoming call.

Instead of relying only on ordinary notifications, Lujayn can present an
incoming-call-style reminder at a scheduled time. The user can answer
the reminder, hear a recorded voice message or spoken reminder, dismiss
it, or snooze it.

The product is being built first for personal use by a small number of
people, with reliability, simplicity and trust as its priorities. It may
eventually be released publicly, but the initial goal is to make it
genuinely useful and dependable.

Lujayn is an independent implementation inspired by the general concept
of call-based reminders. It must not copy another app's branding,
proprietary assets, source code or distinctive interface.

## 2. Product principles

These principles guide every product and engineering decision:

1.  **Privacy by default.** Personal reminders and recordings belong to
    the user.
2.  **Local-first.** Core functionality must work without an internet
    connection.
3.  **No advertising.** No ads or advertising SDKs.
4.  **No tracking.** No analytics, tracking SDKs or behavioural
    profiling.
5.  **No account requirement.** Users should not need to register or
    sign in.
6.  **User control.** Users can create, edit, delete, export and restore
    their own reminder data.
7.  **Reliability over novelty.** A reminder that fails to appear is a
    serious product failure.
8.  **Simple for everyone.** The experience should be comfortable for
    non-technical users, including parents and older users.
9.  **Honest platform behaviour.** Never promise identical call-like
    behaviour on Android and iOS where the operating systems impose
    different restrictions.

The core application should not require internet access. If optional
features ever require network access, they must be clearly separated,
opt-in and documented.

## 3. Target experience

A user should be able to:

-   Open Lujayn and create a reminder quickly.
-   Give the reminder a title and optional description.
-   Choose a date, time and repeat schedule.
-   Choose how the reminder should be presented.
-   Record a personal voice message or use text-to-speech.
-   Receive an incoming-call-style reminder at the scheduled time where
    the platform permits it.
-   Answer, dismiss or snooze the reminder.
-   See upcoming, completed and missed reminders.
-   Manage permissions and understand why they are needed.

Example:

> Remind me every day at 7:00 AM to take my medication.

At the scheduled time, Lujayn presents the reminder using the
platform-appropriate experience. If a voice recording exists, the user
can hear it after answering.

## 4. Feature scope

### MVP: the foundation

The first usable version should focus on:

-   Create, view, edit and delete reminders.
-   One-time reminders.
-   Daily and selected-weekday recurrence.
-   Reminder title and optional description.
-   Date and time selection.
-   Reminder list with clear upcoming/completed states.
-   A basic reminder detail screen.
-   Local persistence.
-   A simple, consistent visual design.
-   Permission/onboarding screens explaining platform requirements.
-   A functional app structure that can later support native alarm and
    notification integration.

The initial frontend may use mock data, but the code should be
structured so the real local repository and scheduling services can
replace mocks without a rewrite.

### Planned features after the initial foundation

**Call-style reminders** - Incoming-call-inspired reminder screen. -
Custom caller display name. - Optional caller image or avatar. - Answer
and dismiss actions. - Custom ringtone and vibration. - Snooze
options. - Reminder-specific presentation settings.

**Voice and speech** - Record a voice reminder. - Play the recording
after answering. - Replace or delete recordings. - Text-to-speech for
typed reminder content. - Audio controls and sensible handling of audio
focus.

**Scheduling** - Weekly, monthly and custom recurrence. - Multiple
reminders for the same task. - Snooze and reschedule. - Missed-reminder
handling. - Reminder history. - Quiet hours and user-configurable
behaviour.

**Personalisation** - Reminder categories. - Custom caller identities. -
Different sounds and vibration settings. - Accessible text sizes and
clear controls. - Home-screen widget, where practical.

**Privacy and data portability** - Local-only storage. - Optional
encrypted local backup and restore. - Clear data export and deletion
controls. - No cloud sync by default.

**Future intelligence** - Optional on-device natural-language reminder
creation. - Example: "Remind me every Monday and Thursday at 6 AM to
water the flowers." - This is not part of the MVP and must not introduce
a mandatory cloud service.

## 5. Technology choices

  -----------------------------------------------------------------------
  Area                                Selected technology
  ----------------------------------- -----------------------------------
  Cross-platform framework            Flutter

  Main application language           Dart

  Android native integration          Kotlin

  Future iOS native integration       Swift

  UI                                  Flutter widgets / Material 3, with
                                      a carefully designed custom visual
                                      identity

  State management                    Riverpod

  Local database                      SQLite using Drift

  Lightweight preferences             SharedPreferences, or an equivalent
                                      maintained Flutter solution

  Android scheduling                  AlarmManager through native Android
                                      integration

  Android event handling              BroadcastReceiver and appropriate
                                      native components

  iOS scheduling                      UserNotifications and other
                                      supported iOS APIs

  Audio                               Flutter audio packages where
                                      suitable, with native integration
                                      when required

  Architecture                        Feature-first, layered architecture
  -----------------------------------------------------------------------

Dependencies must be selected deliberately. Prefer maintained packages
with clear licences, limited permissions and no advertising or analytics
functionality. Review package permissions and transitive dependencies
before adoption.

Do not add a backend, authentication provider, cloud database or
analytics service to the initial application.

## 6. Architecture direction

Flutter owns the shared application experience and business logic.
Platform-specific behaviour belongs behind clearly defined interfaces.

Suggested high-level structure:

``` text
lib/
  app/
    app.dart
    router/
    theme/
  core/
    database/
    errors/
    platform/
    utilities/
    widgets/
  features/
    onboarding/
    reminders/
      data/
      domain/
      presentation/
    settings/
    history/
  main.dart

android/
  app/
    src/
      main/
        kotlin/
          ... native Android integration ...

ios/
  Runner/
    ... future native iOS integration ...
```

The exact folder structure can be adjusted when the project is
initialized, but keep features isolated and avoid putting all logic in
`main.dart`.

Important boundaries:

-   UI screens should not directly schedule operating-system alarms.
-   Reminder creation and recurrence rules should live in testable Dart
    domain logic.
-   A reminder repository should own local persistence.
-   A scheduling abstraction should expose operations such as schedule,
    update, cancel and reschedule.
-   Platform-specific implementations should handle Android and iOS
    differences.
-   Native events should be communicated back to Flutter through a
    deliberate platform integration layer.
-   Mock implementations may be used for early UI development, but
    should be clearly labelled and replaceable.

## 7. Android and iOS constraints

### Android first

Android is the first target because the call-reminder experience is
central to the product.

The implementation must investigate and correctly handle:

-   Exact alarm permissions and access requirements.
-   Full-screen notification permission and eligibility.
-   Notification channels.
-   Android background execution restrictions.
-   Device reboot and alarm rescheduling.
-   Battery optimisation and manufacturer-specific restrictions.
-   Runtime permissions and notification permission onboarding.
-   Actual phone-call state only if genuinely needed; do not request
    unrelated permissions.

Use Android's supported alarm and notification mechanisms. Do not assume
an app can freely launch a full-screen activity at any time.

The incoming-call-style experience should be implemented in a way that
complies with the current Android version's policies and technical
restrictions. Verify behaviour on physical devices, not only emulators.

### iOS later

iOS is a planned future platform, not an MVP requirement.

iOS does not allow an ordinary application to freely imitate a cellular
incoming call or launch arbitrary full-screen interfaces at will. The
iOS version must use supported local notifications and alarm-related
capabilities, with a platform-appropriate reminder interaction.

Share product logic and data models where sensible, but do not force
Android-specific behaviour into a misleading cross-platform abstraction.

## 8. Reliability requirements

Reminder reliability is a core feature.

The full implementation must eventually test:

-   App process killed.
-   Device rebooted.
-   App updated.
-   Reminder edited or deleted.
-   Time zone changed.
-   Daylight-saving changes where applicable.
-   Exact-alarm access revoked or unavailable.
-   Notification permission denied.
-   Battery optimisation enabled.
-   Multiple reminders scheduled close together.
-   Reminder firing while another app is in use.
-   Reminder firing while the device is locked.
-   Audio interrupted by another system event.

When a reminder cannot be guaranteed because a permission is missing,
Lujayn must explain the limitation clearly and provide a path to the
relevant settings.

Never display a false "scheduled successfully" state if the operating
system rejected the scheduling request.

## 9. Design direction

Lujayn should feel personal, calm, modern and dependable.

The app should not look like a generic alarm clock, a corporate
dashboard or a clone of another reminder app.

Design goals:

-   Minimal and uncluttered.
-   Warm, approachable personality.
-   Clear typography and strong readability.
-   Comfortable touch targets.
-   Accessible contrast.
-   Thoughtful empty states.
-   Subtle motion, never motion for its own sake.
-   A distinctive identity that can work with a simple icon and
    wordmark.
-   Light and dark themes can be supported, but do not overcomplicate
    the first UI pass.

The app should feel approachable to a parent who is not particularly
technical. The most important actions must be obvious.

Do not invent a mascot or lock the brand into a particular colour
palette without design exploration.

## 10. Development phases

### Phase 0: Project foundation

-   Initialize Flutter project.
-   Establish folder structure and code conventions.
-   Set up theme, navigation and app shell.
-   Create minimal onboarding and reminder-list UI.
-   Add reminder creation and editing UI using clearly identified mock
    data if persistence is not ready.
-   Add README with setup instructions and project overview.
-   Ensure the project builds and runs.

### Phase 1: Functional reminder foundation

-   Implement reminder models and validation.
-   Implement Drift database and migrations.
-   Implement reminder repository.
-   Implement one-time and basic recurring schedule logic.
-   Add unit tests for date and recurrence calculations.
-   Implement the scheduling abstraction.

### Phase 2: Android reminder delivery

-   Implement native Android alarm scheduling.
-   Implement notification and call-style reminder presentation within
    Android's permitted capabilities.
-   Handle answer, dismiss and snooze.
-   Handle reboot recovery and permission states.
-   Test on physical Android devices.

### Phase 3: Audio

-   Implement voice recording and local file management.
-   Implement playback after answering.
-   Add text-to-speech.
-   Add ringtone and vibration configuration.

### Phase 4: Reliability and privacy

-   Add missed-reminder handling and history.
-   Add backup and restore, with encryption for backups.
-   Test lifecycle, reboot, permissions and battery restrictions.
-   Audit dependencies and permissions.
-   Verify that core functionality works offline.

### Phase 5: Polish and future capabilities

-   Add widgets, categories and advanced recurrence.
-   Explore on-device natural-language creation.
-   Prepare the architecture for iOS.
-   Build the iOS-specific reminder experience using supported Apple
    APIs.

## 11. MVP acceptance criteria

The MVP foundation is ready when:

-   The Flutter project builds and launches.
-   The app has a coherent navigation structure and visual theme.
-   A user can view a reminder list.
-   A user can create and edit a reminder through the UI.
-   Empty, loading and error states are considered.
-   The project has a clear reminder model and repository boundary.
-   Mock data is isolated and easy to replace.
-   No backend, account system, ads or analytics are present.
-   The README explains how to run the project.
-   The code is formatted and basic checks pass.

The initial frontend is not considered a completed reminder engine.
Actual scheduling, background delivery, call-style presentation and
audio must be implemented and tested in subsequent phases.

## 12. Working agreement for AI coding agents

An AI coding agent working on Lujayn should:

1.  Read this document before making changes.
2.  Preserve the product's privacy-first and local-first principles.
3.  Avoid introducing unnecessary dependencies or infrastructure.
4.  Keep the initial implementation small and understandable.
5.  Do not pretend mock functionality is real.
6.  Do not claim that Android or iOS behaviour works without testing it.
7.  Run formatting, analysis and tests before committing.
8.  Explain important architectural decisions in the README or project
    documentation.
9.  Prefer small, reviewable changes over a large speculative
    implementation.
10. Ask before introducing a backend, network dependency, analytics, ads
    or account requirement.

------------------------------------------------------------------------

**Lujayn's defining promise:**

*A personal reminder companion that respects your privacy, stays on your
device and helps you remember what matters.*
