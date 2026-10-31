# Lujayn (لُجَيْن)

> **A personal reminder companion that respects your privacy, stays on your device, and helps you remember what matters.**

Lujayn is an independent, privacy-first, local-first personal reminder application for Android (with future iOS support in mind) built around the concept of simulated incoming-call-style reminders.

Instead of relying solely on easily missed system notification banners, Lujayn is designed to present scheduled reminders in an urgent, human, and calm incoming-call format—allowing users to answer, hear a recorded voice or spoken reminder, dismiss, or snooze.

---

## Core Product Principles

Every product and architectural decision in Lujayn is governed by these 9 non-negotiable principles:

1. **Privacy by default.** Personal reminders and voice recordings belong solely to the user.
2. **Local-first.** Core functionality works completely offline without an internet connection.
3. **No advertising.** Zero ads or advertising SDKs.
4. **No tracking.** Zero analytics, telemetry, tracking SDKs, or behavioral profiling.
5. **No account requirement.** Users never need to register, sign in, or link identity.
6. **User control.** Users retain full control to create, view, edit, delete, export, and restore their data.
7. **Reliability over novelty.** A reminder that fails to fire is a serious product failure.
8. **Simple for everyone.** Accessible and comfortable for non-technical users, parents, and older adults.
9. **Honest platform behavior.** Never promise identical call-like behavior across Android and iOS where operating systems impose different restrictions.

---

## Technology Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (Channel stable, 3.44.8) |
| **Language** | Dart 3.12+ |
| **State Management** | Riverpod (`flutter_riverpod` 3.x with modern `Notifier` & `NotifierProvider`) |
| **UI Design System** | Custom Material 3 theme (Slate Teal, Warm Amber, Calm Sage), high contrast, accessible touch targets (min 48dp) |
| **Architecture** | Feature-first layered architecture (Domain, Data, Presentation) |
| **Planned Persistence** | Drift SQLite (`drift` / `drift_flutter` in Phase 1; clean in-memory mock repository in Phase 0) |
| **Planned Android Engine** | Native Kotlin integration via `AlarmManager`, `BroadcastReceiver`, and full-screen notifications (Phase 2) |
| **Planned Audio** | Local voice recording, audio playback, and text-to-speech (Phase 3) |

---

## Project Structure

```text
lib/
├── app/
│   ├── app.dart                   # Root MaterialApp with theme bindings
│   ├── shell/
│   │   └── app_shell.dart         # Adaptive bottom navigation bar (Reminders, Settings)
│   └── theme/
│       ├── app_colors.dart        # Semantic design tokens (Slate Teal, Warm Amber, Sage)
│       ├── app_theme.dart         # Material 3 light and dark theme definitions
│       └── app_typography.dart    # Legible typography scale designed for accessibility
│
├── core/
│   ├── database/
│   │   └── app_database.dart      # Database contract & Drift architecture blueprint
│   ├── utilities/
│   │   └── date_formatters.dart   # Human-friendly date and time formatters
│   └── widgets/
│       ├── empty_state_view.dart  # Calm illustration/icon empty state presentation
│       ├── honest_notice_card.dart# Transparent indicator of current stage constraints
│       ├── responsive_center.dart # Constrained width wrapper for tablet/desktop viewports
│       └── section_header.dart    # List grouping header with count badges
│
└── features/
    ├── reminders/
    │   ├── data/
    │   │   ├── models/            # DTOs and database mapping contracts
    │   │   └── repositories/
    │   │       ├── mock_reminder_repository.dart   # Isolated in-memory reactive repository
    │   │       └── drift_reminder_repository.dart  # Phase 1 Drift SQLite placeholder
    │   ├── domain/
    │   │   ├── models/
    │   │   │   ├── recurrence_rule.dart            # Recurrence calculations & schedule rules
    │   │   │   ├── reminder.dart                   # Immutable domain reminder entity
    │   │   │   └── reminder_status.dart            # Active, completed, snoozed, dismissed
    │   │   └── repositories/
    │   │       └── reminder_repository.dart        # Abstract persistence contract
    │   └── presentation/
    │       ├── controllers/
    │       │   └── reminder_providers.dart         # Riverpod stream & filter providers
    │       ├── screens/
    │       │   ├── home_screen.dart                # Upcoming, Completed, and All reminders list
    │       │   ├── reminder_detail_screen.dart     # Comprehensive detail, edit & delete view
    │       │   └── reminder_form_screen.dart       # Create / edit form with date, time, repeat
    │       └── widgets/
    │           ├── recurrence_chip_selector.dart   # One-time, Daily, Weekdays, Weekly selector
    │           └── reminder_card.dart              # Interactive reminder card with completion circle
    │
    └── settings/
        └── presentation/
            ├── controllers/
            │   └── settings_providers.dart         # Theme mode controller (System, Light, Dark)
            ├── screens/
            │   └── settings_screen.dart            # Privacy, platform primers, appearance, about
            └── widgets/
                └── principles_dialog.dart          # Dialog presenting Lujayn's 9 core principles
```

---

## Current Implementation Status: Phase 0 (Foundation)

| Feature / Area | Status | Notes |
|---|---|---|
| **Project Setup** | Completed | Flutter project initialized with Android, iOS, and Linux desktop targets |
| **Architecture** | Completed | Feature-first clean architecture separating domain, data, and presentation |
| **State Management** | Completed | Riverpod 3 NotifierProviders wired for reminders, filters, and theme mode |
| **Visual Design** | Completed | Polished light & dark theme, typography, comfortable touch targets |
| **Home Screen** | Completed | Segmented filters (Upcoming, Completed, All), grouped by Today/Later |
| **Creation & Edit** | Completed | Form with title validation, notes, date picker, quick time presets, recurrence selector |
| **Sample Data** | Completed | 5 realistic, human sample reminders preloaded into isolated mock repository |
| **Settings Screen** | Completed | Privacy transparency, platform permission primer, appearance switch, principles modal |
| **Drift Architecture** | Prepared | Database contracts and repository interfaces ready for Phase 1 code generation |
| **Native Alarms & Audio**| Out of Scope (Phase 2 & 3)| Not simulated or faked; transparently documented |

---

## Development Setup

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`3.44.8` or compatible stable channel)
- Dart SDK `^3.12.2`
- Android Studio / Android SDK (for Android builds) or Linux build tools (`clang`, `cmake`, `ninja-build`)

### Getting Started

1. **Clone the repository:**
   ```bash
   git clone git@github.com:Adams-404/lujayn.git
   cd lujayn
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run static analysis:**
   ```bash
   flutter analyze
   ```

4. **Run unit and widget tests:**
   ```bash
   flutter test
   ```

5. **Format code:**
   ```bash
   dart format .
   ```

6. **Launch the application:**
   - On Linux desktop:
     ```bash
     flutter run -d linux
     ```
   - On Android emulator or device:
     ```bash
     flutter run -d android
     ```
   - In Chrome (web preview):
     ```bash
     flutter run -d chrome
     ```

---

## Road Map

- **Phase 0 (Current):** Project foundation, architecture, theme, navigation, reminder creation, mock repository.
- **Phase 1:** Drift SQLite database persistence, migrations, and recurrence calculation unit tests.
- **Phase 2:** Android native alarm scheduling (`AlarmManager`), exact alarm permissions, and full-screen notification presentation.
- **Phase 3:** Voice recording, audio playback upon answering, text-to-speech fallback, and sound/vibration customization.
- **Phase 4:** Missed reminder handling, local encrypted backup & export, lifecycle recovery testing.
- **Phase 5:** Home screen widgets, iOS UserNotifications integration, and accessibility refinements.

---

## License

Private and personal project. All rights reserved.
