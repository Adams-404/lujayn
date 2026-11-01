# Lujayn contributor and coding-agent guide

Lujayn is an offline-first personal reminder app. Reliability, privacy, accessibility, and clarity matter more than adding features quickly.

## Non-negotiable product rules

- Keep reminder content, voice recordings, and preferences on-device by default.
- Do not add accounts, a backend, analytics, ads, cloud sync, or network dependencies without explicit product approval.
- Do not request contacts, call logs, SMS, or unrelated permissions.
- Never claim an alarm or full-screen reminder is guaranteed on every Android device. Document OS and OEM restrictions.
- Keep domain logic independent of Flutter widgets, storage, and Android APIs.
- Treat missed reminders as a reliability bug, not a cosmetic issue.
- Preserve the simple experience for people who are not technically confident.

## Before changing code

1. Read `lujayn-project-brief.md` and the relevant feature code.
2. For any visual or interaction change, read `.agents/skills/lujayn-mobile-design/SKILL.md` and `docs/design-direction.md`.
3. Inspect existing abstractions and reuse them. Do not create duplicate providers, repositories, theme layers, or helpers.
4. Keep dependencies minimal and explain why a new dependency is needed.
5. Add or update tests with behaviour changes. Never claim tests or physical-device checks that were not run.

## Current architecture

- Flutter and Dart, Android first.
- Riverpod for presentation state and dependency wiring.
- Domain models and repository contracts under `lib/features/**/domain`.
- Data implementations under `lib/features/**/data`.
- Shared app shell, theme, and core widgets under `lib/app` and `lib/core`.
- Drift/SQLite for local persistence.

## Quality gate

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
```

If a command cannot be run, state that clearly and use CI as the verification gate. For Android alarm, notification, audio, and reboot behaviour, include a physical-device test matrix.

## UI work

Use the Lujayn mobile design skill and `docs/design-direction.md`. Every screen must work across Silver, Paper, Sage, Dusk, and AMOLED, handle relevant UI states, support text scaling, and use semantic theme tokens instead of hardcoded colours.