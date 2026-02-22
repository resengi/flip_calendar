# CHANGELOG

<!-- version list -->

## 0.1.0

- Initial release of `flip_calendar` — a month calendar widget with realistic page-turn animations powered by `page_turn_animation`.
- Swipe gesture navigation with flick detection, configurable thresholds, and support for all four bound edges (top, bottom, left, right).
- `CalendarController` for programmatic navigation with `isAnimating` state for coordinating external UI.
- Flexible date constraints via `DateConstraint` — supports fixed, relative, and dynamic (e.g., today) boundaries for both navigation and selection.
- Fully customizable day cell rendering through `dayBuilder` with `CalendarDayData` providing per-cell state (today, selected, enabled, current month, etc.).
- `CalendarStyle` with built-in light and dark presets, `copyWith` support, and fine-grained control over grid, header, animation, and gesture behavior.