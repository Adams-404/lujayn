# Caller Persona & Interactive Call Simulation

Lujayn simulates an incoming phone call when a reminder alerts. This document
describes how Caller Personas and the in-call simulation work, and how they
respect the project's non-negotiable product principles.

---

## 1. Non-negotiable Privacy Boundary

> "Do not request contacts, call logs, SMS, or unrelated permissions."
> — `AGENTS.md`

Requesting Android's `READ_CONTACTS` permission requires broad access to the
entire user address book and triggers high-friction security prompts.

To uphold Lujayn's privacy-first foundation:
- **No device contact permissions are ever requested or queried.**
- Users select from curated built-in presets (e.g. *Family / Mom*, *Doctor / Clinic*, *Work*, *Friend*) or type their own custom caller name and label.
- Personas are persisted purely in the local SQLite database (`caller_name`, `caller_number`, `caller_icon`).

---

## 2. Interaction Flow

### A. Incoming Call Alert (Ringing State)
When a reminder alerts via `ReminderCallScreen`:
1. Top label shows `INCOMING CALL` (or `REMINDER` if persona is unset) with scheduled time.
2. Caller Badge renders the initials or thematic icon (heart for Family, medical cross for Doctor, briefcase for Work, smile for Friend, person for Custom).
3. Caller Name (e.g. "Mom ❤️") and Number/Label (e.g. "Mobile • (555) 019-2831") are displayed prominently.
4. Reminder title is displayed in a calm secondary pill badge.
5. Primary action: **Answer Call** (prominent filled button).
6. Alternative direct actions: **Done** (completes/dismisses) and **Snooze 10 minutes**.

### B. Answered Call Simulation (In-Call State)
Tapping **Answer Call**:
1. Triggers tactile haptic feedback.
2. Updates header to `CONNECTED • 00:00` and starts a 1-second live duration timer.
3. Automatically plays audio:
   - If the reminder has a recorded voice note, playback starts immediately.
   - If no voice note exists but the speech engine is available, reads the reminder title and note aloud with dialpad guidance.
4. Reveals the interactive **Dialpad Keypad**:
   - **Key 1 (Done)**: Completes the reminder (or dismisses current occurrence) and ends the call.
   - **Key 2 (Reschedule)**: Snoozes the reminder for 10 minutes and ends the call.
   - **Key 3 (Keep Active)**: Ends the call while keeping the reminder active.
5. Displays a red **Hang Up** button to terminate the call, stop audio playback, and close the screen.

---

## 3. Database Schema Migration (v2 -> v3)

Drift schema version was bumped from 2 to 3 with non-destructive migrations:
```dart
if (from < 3) {
  await migrator.addColumn(reminders, reminders.callerName);
  await migrator.addColumn(reminders, reminders.callerNumber);
  await migrator.addColumn(reminders, reminders.callerIcon);
}
```

---

## 4. Verification

- All five themes (`silver`, `slate`, `olive`, `copper`, `clay`) verified with widget tests.
- 200% text scaling verified without overflow.
- All unit, repository, and widget tests pass locally.
