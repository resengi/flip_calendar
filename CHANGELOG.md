# Change Log



## 2026-02-22

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`flip_calendar` - `v0.1.1`](#flip_calendar---v011)

---

#### `flip_calendar` - `v0.1.1`

 - **FEAT**: Initial open sourcing of flip calendar package ([#1](https://github.com/resengi/flip_calendar/issues/1)). ([ff57fc54](https://github.com/resengi/flip_calendar/commit/ff57fc546f7a2bafd55fc9a297f44399c68fe25d))

## 0.1.1

 - **FEAT**: Initial open sourcing of flip calendar package ([#1](https://github.com/resengi/flip_calendar/issues/1)). ([ff57fc54](https://github.com/resengi/flip_calendar/commit/ff57fc546f7a2bafd55fc9a297f44399c68fe25d))

# CHANGELOG

<!-- version list -->

## 0.1.0

- Initial release of `flip_calendar` — a month calendar widget with realistic page-turn animations powered by `page_turn_animation`.
- Swipe gesture navigation with flick detection, configurable thresholds, and support for all four bound edges (top, bottom, left, right).
- `CalendarController` for programmatic navigation with `isAnimating` state for coordinating external UI.
- Flexible date constraints via `DateConstraint` — supports fixed, relative, and dynamic (e.g., today) boundaries for both navigation and selection.
- Fully customizable day cell rendering through `dayBuilder` with `CalendarDayData` providing per-cell state (today, selected, enabled, current month, etc.).
- `CalendarStyle` with built-in light and dark presets, `copyWith` support, and fine-grained control over grid, header, animation, and gesture behavior. `CalendarStyle` with built-in light and dark presets, `copyWith` support, and fine-grained control over grid, header, animation, and gesture behavior.