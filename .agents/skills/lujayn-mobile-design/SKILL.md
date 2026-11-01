---
name: lujayn-mobile-design
description: Use when designing, implementing, refactoring, or reviewing any Lujayn Flutter screen, component, interaction, navigation flow, theme, or accessibility behaviour. Applies to Android-first Flutter UI and future iOS adaptation. Triggers on UI redesigns, new screens, forms, settings, reminder flows, theme changes, and visual QA.
---

# Lujayn mobile design skill

Design Lujayn like a considered personal product, not a generic generated dashboard. The interface should feel calm, human, quietly distinctive, and dependable. It must remain easy for a parent or first-time smartphone user to understand.

## Read first

- `docs/design-direction.md`
- `lujayn-project-brief.md`
- Existing screen, route, theme, and shared-widget code for the flow being changed.

## Design loop

1. **Define the task.** State the user's goal, the primary action, and what success looks like. Do not begin with decoration.
2. **Map the flow.** Identify entry point, next step, back behaviour, destructive actions, and recovery from failure.
3. **Check platform fit.** Use idiomatic Android Material 3 behaviour. Respect system bars, navigation, keyboard, safe areas, notification permissions, and Android back navigation. Do not imitate a phone call beyond what platform APIs permit.
4. **Reuse before adding.** Inspect existing widgets, providers, theme tokens, and navigation. Add a new abstraction only when it removes real duplication or clarifies behaviour.
5. **Design all relevant states.** Consider first-use/empty, populated, loading, error, offline, success, disabled, and permission-denied states. Do not leave dead ends.
6. **Use semantic tokens.** All colours, text styles, spacing, radii, borders, and component states must come from the shared design system. Never hardcode screen-specific palette values.
7. **Design for hands and eyes.** Keep primary actions reachable, target at least 48dp on Android, support text scaling, maintain clear contrast, and give controls meaningful semantics and labels.
8. **Check localisation.** Avoid fixed-width text assumptions and left/right-only layout logic. Preserve a future path for Hausa and RTL layouts.
9. **Review every theme.** Check the screen in Silver, Paper, Sage, Dusk, and AMOLED. Never assume a light/dark pair is enough.
10. **Verify.** Run formatter, analyzer, tests, and a visual pass on a compact Android viewport. Report any checks that could not be run.

## Lujayn art direction

- **Silver is the brand cue, not a mandate to make everything metallic.** Use quiet neutral surfaces, precise typography, and a restrained silver/graphite accent.
- Prefer a clear editorial hierarchy: a useful page title, one primary action, concise supporting text, and a readable schedule.
- Make the next reminder and its time the visual priority on the home screen. Real reminder content should occupy the interface, not invented statistics.
- Use cards only when they group information or actions. Lists, dividers, whitespace, and typography are often better.
- Use motion to communicate state changes, not as decoration. Respect reduced-motion settings.
- Keep call-style reminder UI distinct, focused, high-contrast, and immediately actionable.
- Make reminder creation feel like a short, guided task. Reveal advanced recurrence controls only when needed.

## Avoid these failure patterns

- Generic dashboard layouts, stat tiles, charts, fake activity, and filler content.
- A floating action button plus several equally prominent CTAs competing for attention.
- Gradients used as a substitute for hierarchy or brand identity.
- Glassmorphism, excessive blur, excessive pill shapes, or every element inside a rounded card.
- Arbitrary per-screen colours, spacing, radii, and typography.
- Tiny low-contrast metadata, icon-only controls without labels, or touch targets below 48dp.
- Custom navigation that fights Android conventions.
- Beautiful success screens that ignore empty, error, offline, and permission-denied states.

## Required design handoff for multi-screen work

- User goal and primary action.
- Screen hierarchy and navigation behaviour.
- Relevant states and recovery paths.
- Tokens/components to reuse or add.
- Behaviour differences across the five themes.
- Accessibility and responsive considerations.
- Tests and visual checks to run.

## Review checklist

- [ ] Purpose and primary action are clear at first glance.
- [ ] No invented dashboard content or decorative metrics.
- [ ] Existing components and architecture were checked before adding new ones.
- [ ] All relevant states have useful copy and a recovery path.
- [ ] Touch targets are at least 48dp and controls have semantic labels.
- [ ] Text scaling does not clip or hide important actions.
- [ ] Colours and typography come from semantic tokens.
- [ ] Silver, Paper, Sage, Dusk, and AMOLED all remain legible.
- [ ] AMOLED uses true black for its main background surfaces.
- [ ] Android navigation, safe areas, and system UI are respected.
- [ ] Formatter, analyzer, tests, and visual review are reported honestly.

## External references

This project-specific skill is original guidance informed by established platform and agent-design references. Consult current documentation when implementation details may have changed:

- [Material Design 3](https://m3.material.io/)
- [Flutter theming](https://docs.flutter.dev/cookbook/design/themes)
- [Android app quality guidance](https://developer.android.com/docs/quality-guidelines)
- [Mobile App UI/UX Pro Max](https://github.com/noumanzindani/mobile-app-uiux-pro-max-skill) for an example of a token-driven, state-complete mobile design skill (Apache-2.0; not vendored here)
- [Mobile Design skill](https://github.com/RubenGlez/mobile-design) for mobile interaction and accessibility review patterns

Do not blindly follow a reference if it conflicts with Lujayn's privacy requirements, Android platform behaviour, or the existing architecture.