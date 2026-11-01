# Lujayn visual direction

## Product feeling

Lujayn should feel like a thoughtful personal companion: calm, warm, precise, and dependable. It is not a productivity dashboard. The interface should help someone remember something and then get out of the way.

The name means silver. Use that as a quiet identity cue through graphite, soft mineral neutrals, and a restrained silver accent. Do not turn the app into a chrome/metal texture theme.

## Five named themes

| Theme | Role | Surface direction | Accent direction |
|---|---|---|---|
| Silver | Signature light | Cool off-white, clean paper-like surface, subtle graphite borders | Muted silver/blue graphite |
| Paper | Warm light | Warm ivory and parchment neutrals | Deep ink / muted terracotta |
| Sage | Nature-inspired | Pale mineral green, low-saturation surfaces | Forest green |
| Dusk | Dark | Deep charcoal, layered dark surfaces | Soft silver / muted lilac |
| AMOLED | OLED dark | True black (#000000) main background with carefully separated near-black content surfaces | Cool silver |

These are five distinct palettes, not five wallpaper tints. Each must define semantic roles for background, surface, elevated surface, primary text, secondary text, outline, primary action, on-primary, secondary action, error, success, and focus. Contrast must be checked for each theme.

System appearance may be offered as a separate mode if the theme architecture supports it, but it must not remove any of the five named choices.

## Layout and hierarchy

- Home: date/context, next reminder (if one exists), then a chronological schedule. Avoid counts and metrics unless they help the user act.
- Reminder creation: title and date/time first. Optional description and recurrence should be clear without overwhelming the first-use flow.
- Detail: title, when it happens, recurrence, optional note/voice content, and a small set of clear actions.
- Settings: plain-language grouped preferences. Explain permissions before requesting them.
- Call-style reminder: large readable reminder title, clear time/context, and obvious answer/dismiss/snooze actions. Do not imply a real cellular call.

## Component language

- Prefer typographic hierarchy, alignment, spacing, and thin dividers over nested cards.
- Use one main accent per theme. Reserve semantic colours for status and destructive actions.
- Corners should be consistent and purposeful. Do not round every surface into a pill.
- Use elevation sparingly. Prefer tonal surface differences and borders.
- Use icons as navigation or action cues, not as decoration.
- Keep animations short and functional. Respect reduced motion.

## Accessibility and resilience

- Minimum Android touch target: 48dp.
- Support system font scaling and avoid fixed-height text containers.
- Never communicate status through colour alone.
- Ensure labels and reading order are meaningful for screen readers.
- Keep all essential actions usable with large text and on narrow devices.
- Keep layout strings localisation-ready and directional.
- Test every screen in all five themes, including dialogs, bottom sheets, snackbars, and call-style UI.

## Anti-patterns

Generic stat tiles, fake usage charts, generic gradient hero banners, glass cards, excessive pill buttons, nested rounded rectangles, low-contrast metadata, tiny tap targets, and one-off hardcoded colours are not part of Lujayn's visual language.