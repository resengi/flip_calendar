# Flip Calendar — Example

A demo app showcasing the `flip_calendar` package. It presents a fully
interactive month calendar with page-turn animations, swipe gesture navigation,
and sample event data.

## Running the Example

Make sure you are in the example directory, then run:

```bash
flutter pub get
flutter run
```

You may need to run `flutter create .` if it is your first time launching the example.

## What It Demonstrates

- **Swipe gesture navigation** with flick detection for quick month changes
- **Programmatic navigation** via `CalendarController` (prev/next buttons,
  jump to today)
- **Waiting for the calendar** — the jump to today waits for the calendar to be
  on screen (`whenShown`) and for the page turn to end (`whenAtRest`)
- **All four bound edges** (top, bottom, left, right) via a dropdown selector,
  which also switches the gesture axis between vertical and horizontal
- **Custom day cell rendering** using `dayBuilder` with event indicator dots
- **Date constraints** using `DateConstraint.today()` on the controller to
  disable future dates
- **A host clock** — the controller reads a clock the app updates every minute,
  so today follows the day while the app is open
- **Navigation state awareness** — the header's buttons and title are disabled
  while a navigation is in progress, via `CalendarController.isNavigating`
- **Custom styling** via `CalendarStyle` and `PageTurnStyle` (colors, grid
  lines, border radius, shadow, curl intensity)

## How It Works

The example is a single `main.dart` with no external dependencies beyond
`flip_calendar` and `page_turn_animation`:

1. **CalendarController** — holds the month, today (from the app's clock), the
   upper bound and the animation mode, and notifies listeners when the month,
   the day or the navigation state changes.
2. **CalendarHeader** — a responsive month/year display with chevron navigation.
   Tapping the title turns to today's month and clears the selection once the
   page rests there.
3. **DayCell** — a custom day builder that shows the day number and up to four
   colored event dots. Days of the adjacent months are faded, disabled dates
   use a muted text color, and today is highlighted with the accent color.
4. **BoundEdgePicker** — a dropdown at the bottom that lets you switch which
   edge the page curls over, useful for previewing all animation directions.

Sample events are hard-coded on a handful of days of every month so the
calendar has visual content without needing a data layer.
