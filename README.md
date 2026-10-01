# Flip Calendar

A customizable Flutter month calendar widget with realistic page-turn animations and swipe gesture navigation, powered by [page_turn_animation](https://pub.dev/packages/page_turn_animation).

[![pub package](https://img.shields.io/pub/v/flip_calendar.svg)](https://pub.dev/packages/flip_calendar)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Publisher](https://img.shields.io/pub/publisher/flip_calendar.svg)](https://pub.dev/publishers/resengi.io)

<table>
  <tr>
    <td><img src="https://raw.githubusercontent.com/resengi/flip_calendar/main/assets/top_edge_example.gif" width="200" alt="Top edge demo"></td>
    <td><img src="https://raw.githubusercontent.com/resengi/flip_calendar/main/assets/bottom_edge_example.gif" width="200" alt="Bottom edge demo"></td>
    <td><img src="https://raw.githubusercontent.com/resengi/flip_calendar/main/assets/left_edge_example.gif" width="200" alt="Left edge demo"></td>
    <td><img src="https://raw.githubusercontent.com/resengi/flip_calendar/main/assets/right_edge_example.gif" width="200" alt="Right edge demo"></td>
  </tr>
  <tr>
    <td align="center">Top</td>
    <td align="center">Bottom</td>
    <td align="center">Left</td>
    <td align="center">Right</td>
  </tr>
</table>

## Features

- Realistic 3D page curl effect when navigating between months
- Swipe gesture navigation with flick detection
- Fully customizable day cell rendering via builder
- Programmatic navigation with `CalendarController`, with a busy signal and futures to wait on
- Date constraints (min/max): fixed dates, or dates relative to today
- A host clock for "today", so the calendar follows the day while the app is open
- Several calendars on one controller
- Configurable bound edge (top, bottom, left, right)
- Sequential or direct-jump multi-month animation modes
- Built-in light and dark theme presets
- A haptic feedback hook for swipes that cannot navigate
- Works with any first day of week (Monday, Sunday, etc.)

## Requirements

Flutter 3.41.0 or later.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flip_calendar: ^0.1.0
  page_turn_animation: ^0.1.4
```

Then run:

```bash
flutter pub get
```

`page_turn_animation` provides `PageTurnEdge` and `PageTurnStyle`; import it wherever you use them.

## Quick Start

```dart
import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter/material.dart';

class MyCalendar extends StatefulWidget {
  const MyCalendar({super.key});

  @override
  State<MyCalendar> createState() => _MyCalendarState();
}

class _MyCalendarState extends State<MyCalendar> {
  final _controller = CalendarController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlipCalendar(
      controller: _controller,
      selectedDate: _selectedDate,
      onDayTap: (date) => setState(() => _selectedDate = date),
      dayBuilder: (context, data) {
        return Center(
          child: Text(
            data.date.day.toString(),
            style: TextStyle(
              color: data.isCurrentMonth ? Colors.black : Colors.grey[400],
              fontWeight: data.isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      },
    );
  }
}
```

The calendar fills the space it is given, which must be bounded in both directions (see [Sizing](#sizing)).

## Usage Guide

### CalendarController

The `CalendarController` holds everything the calendar's navigation depends on: the month the calendar is on, today, the allowed range, the animation settings, and whether a navigation is in progress. Create it once, pass it to `FlipCalendar`, and dispose it when you are done:

```dart
final controller = CalendarController(
  // initialMonth defaults to today's month, which must have an allowed day.
  minDate: DateConstraint.relative(years: -1),
  maxDate: DateConstraint.today(),
  animationsEnabled: true,
  maxAnimatedMonthJump: 6,
  multiMonthAnimationMode: MultiMonthAnimationMode.sequential,
);

controller.addListener(() {
  debugPrint('${controller.currentMonth} ${controller.isNavigating}');
});

// Programmatic navigation
controller.nextMonth();
controller.previousMonth();
controller.goToMonth(DateTime(2025, 12, 1));
controller.goToToday();
controller.goToYearMonth(2026, 3);
```

**One navigation at a time.** While a calendar plays a navigation, `isNavigating` is true and every other request is ignored: nothing changes and nothing is notified. In the snippet above, with a calendar using the controller, only `nextMonth()` is accepted. To make several moves, wait for each to end with `whenAtRest()`:

```dart
controller.nextMonth();
await controller.whenAtRest();
controller.goToMonth(DateTime(2025, 12, 1));
```

`whenAtRest()` completes at once when no navigation is in progress. A swipe is a navigation too: `isNavigating` turns on when a drag begins, and a request made during the drag is ignored.

**Where a request lands.** `currentMonth` is the first day of the month the calendar rests on. An accepted request sets it at once, so it can be read right after the call, while the calendar still turns the pages on the way. A request for a month with no allowed day lands on the allowed month nearest the target, among the allowed months in the request's direction; if there is none, or it would land on the current month, nothing happens. With no calendar using the controller, an accepted request still changes the month, and the controller never becomes busy.

**Notifications.** Listeners are notified when `currentMonth`, the bounds, the animation settings or `isNavigating` change, and, with a clock, when the day of `today` changes; setting a value to what it already is notifies nothing. A change made while Flutter builds, lays out or paints a frame is announced after that frame.

**Flutter's binding.** Calls that notify listeners need Flutter's binding, which an app has once `runApp` (or `WidgetsFlutterBinding.ensureInitialized()`) has run. In a plain `test()`, call `TestWidgetsFlutterBinding.ensureInitialized()` first.

**Disposing.** After `dispose()`, `whenAtRest()` and `whenShown()` complete at once, and so do the calls already waiting on them: check that your widget is still mounted before you use the controller after an `await`. A call that notifies listeners after `dispose()` raises `ChangeNotifier`'s debug assertion.

### Several Calendars on One Controller

Any number of calendars can use one controller, and a calendar can switch to another controller at any time; it then moves to the new controller's month at once. Every calendar plays each navigation, and `isNavigating` stays on until all of them have shown the result. A calendar that is removed stops counting. When one calendar is swiped to a new month, the others turn to it after the swipe's page turn. Calendars on one controller share its animation settings, but can differ in style, `boundEdge` and `gesturesEnabled`.

### Day Builder

The `dayBuilder` callback receives a `CalendarDayData` object with everything you need to render each cell:

```dart
FlipCalendar(
  controller: controller,
  dayBuilder: (context, data) {
    // data.date           — the date this cell represents
    // data.isCurrentMonth — false for days of the adjacent months
    // data.isToday        — whether this date is the controller's today
    // data.isSelected     — whether this date is selectedDate's day
    // data.isFutureDate   — whether this date is after today
    // data.isEnabled      — whether this date is within the bounds
    // data.row / data.column — the cell's place in the grid (0-based)

    return Center(
      child: Text(
        data.date.day.toString(),
        style: TextStyle(
          color: data.isEnabled ? Colors.black : Colors.grey,
        ),
      ),
    );
  },
)
```

A page shows whole weeks: 4 to 6 rows of 7 days, starting with days of the previous month and ending with days of the next. `onDayTap` is called with the date of any enabled day that is tapped, including days of the adjacent months; disabled days do not respond to taps.

### Date Constraints

The allowed range is set on the controller, when it is created or later with `setBounds`, using `DateConstraint`:

```dart
// Fixed dates
final controller = CalendarController(
  minDate: DateConstraint.fixed(DateTime(2020, 1, 1)),
  maxDate: DateConstraint.fixed(DateTime(2030, 12, 31)),
);

// Up to today
controller.setBounds(null, DateConstraint.today());

// Relative: 2 years back, 1 year ahead
controller.setBounds(
  DateConstraint.relative(years: -2),
  DateConstraint.relative(years: 1),
);

// No bounds
controller.setBounds(null, null);
```

- A constraint holds a rule, not a date. The controller resolves it against its `today` whenever it needs the date, so `today()` and `relative(...)` move with the day.
- `relative` adds years and months first, keeping today's day of the month but capping it at the last day of the resulting month, then adds days: from January 31, `months: 1` gives the last day of February, and `months: 1, days: 1` gives March 1.
- `fixed` keeps only the date's calendar day.
- Both bounds are inclusive. Days outside them are disabled. An accepted navigation chooses a destination with an allowed day at acceptance; a sequential animation can display disabled intermediate months.
- `setBounds` replaces both bounds and notifies only if a bound changed. Constraints compare by their rule: `DateConstraint.today()` equals `DateConstraint.relative()`, but `relative(years: 1)` does not equal `relative(months: 12)`.
- A month that loses its allowed days while it is shown (because the bounds or today changed) stays shown, with its days disabled.
- Bounds that cross later, as today moves, are not an error: no month is allowed, and every request moves nothing.

To ask about the range, use `isDateAllowed(date)`, `canGoTo(month)` (the month supports a complete grid and has an allowed day), `firstAllowedMonth` and `lastAllowedMonth`.

Displayed months run from May -271821 through August 275760. These complete months leave room for every first-day-of-week layout within [Dart's DateTime range](https://api.dart.dev/dart-core/DateTime-class.html). `canGoTo` returns false outside that display range; navigation requests use the same nearest-allowed-month rule. Constraints resolve representable individual days, including days in the partial endpoint months.

`firstAllowedMonth` and `lastAllowedMonth` return the first local date of each explicit bound's month, or null for an open side. When bounds cross, the getters retain the bound months even though no month is allowed. A getter throws if that first local date is outside DateTime's range.

### Today and the Clock

`controller.today` is today's date, which marks `isToday` and `isFutureDate` and resolves the bounds. By default it is read from the device clock when needed, and the calendar shows a new day only when something rebuilds it. To have the calendar follow the day while the app is open, give the controller a clock:

```dart
final clock = ValueNotifier<DateTime>(DateTime.now());
// Update it from your own timer, for example once a minute:
// clock.value = DateTime.now();

final controller = CalendarController(clock: clock);
```

`today` is then the calendar day of the clock's value, and listeners are notified when that day changes; a tick on the same day notifies nothing. The clock is fixed for the controller's life and must outlive it: to change what drives the calendar, change the clock's value rather than the clock. A change of today never moves the month.

### Calendars That Aren't on Screen

A calendar is on screen when it is painted with its animations running. A request that finds a calendar not on screen (on a hidden tab, under another route, or with its animations paused by a `TickerMode`) changes its month at once, without a page turn; when it is shown again, it is already on the new month. A page turn whose animations pause partway waits, with `isNavigating` still on, and finishes once they resume.

To have a calendar that may be hidden turn its pages once it is shown, for example after a notification tap switches to its tab, wait for `whenShown()` before asking which months it will show and navigating:

```dart
await controller.whenShown();
final pages = controller.monthsOnWayTo(september);
await loadMonths(pages); // your own data loading
controller.goToMonth(september);
await controller.whenAtRest();
```

- `whenShown()` completes once a calendar using the controller is on screen. If none uses it yet, it waits for one.
- `monthsOnWayTo(month)` lists the months a navigation to `month` would show, in order, ending with the month it would land on. It is empty if nothing would move, including while a navigation is in progress. It answers as if the calendar is on screen; a calendar that is not on screen shows only the last month. The answer is exact for a request made right after asking.

### Choosing the Bound Edge

The `boundEdge` parameter controls which edge the page curls over, and determines whether swipe gestures are vertical or horizontal. A swipe toward the bound edge goes to the next month, and a swipe away from it to the previous month:

```dart
// Top-bound (default): swipe up/down to navigate
FlipCalendar(
  controller: controller,
  boundEdge: PageTurnEdge.top,
  dayBuilder: dayBuilder,
)

// Right-bound: swipe left/right
FlipCalendar(
  controller: controller,
  boundEdge: PageTurnEdge.right,
  dayBuilder: dayBuilder,
)
```

| Edge | Gesture | Next month | Use Case |
|------|---------|------------|----------|
| `top` | Vertical | Swipe up | Top-bound notepad (default) |
| `bottom` | Vertical | Swipe down | Wall calendar, bottom-bound pad |
| `left` | Horizontal | Swipe left | Right-to-left book, manga |
| `right` | Horizontal | Swipe right | Left-to-right book, standard Western reading |

### Swipes

- A swipe follows the finger that started it; other fingers are ignored until it lifts. Its direction is the direction of its first move along the swipe axis.
- While the finger moves, the page follows it: the distance moved along the axis, over `dragBoxSizePercentage` of the calendar's size along the axis. Moving back past the start leaves the page flat; a swipe never turns the other way.
- On release, a flick in the swipe's direction completes it and a flick against it does not. Without a flick, the swipe completes when the page is turned at least `dragProgressThreshold` of the way. A flick is a release faster than `flickDistanceThreshold` of the calendar's size along the axis per `flickMaxDuration`, that has also moved more than Flutter's touch slop just before it.
- A swipe that does not complete turns the page back, and the month does not change. A cancelled pointer, the calendar collapsing to no size, a change of `boundEdge`, turning `gesturesEnabled` off, or an input that fails its check (see [Validation](#validation)) ends a swipe the same way.
- A swipe toward a month outside the bounds, with no allowed month beyond it in that direction, cannot land: the page lifts slightly and turns back, and `onHapticFeedback` is called once with `CalendarHapticType.navigationRestricted` when the swipe starts. With animations off, only the haptic happens.
- A swipe out of a month that is outside the bounds, toward the allowed range, turns straight to the nearest allowed month in one page turn.
- If the swipe's month becomes forbidden before the swipe lands, the calendar returns to the controller's month.
- Swipes work with animations off: a completed swipe changes the month without a page turn.

### Multi-Month Animation Modes

The controller's `multiMonthAnimationMode` sets how a navigation request turns the pages when animations are enabled. It applies to every request, including one to the next or previous month:

```dart
// Sequential: one page turn per month moved (default)
controller.multiMonthAnimationMode = MultiMonthAnimationMode.sequential;
controller.maxAnimatedMonthJump = 6; // longer moves change without a turn

// Direct jump: one page turn from the current month to the target
controller.multiMonthAnimationMode = MultiMonthAnimationMode.directJump;
```

| Mode | Behavior |
|------|----------|
| `sequential` | One page turn per month moved, if the request moves at most `maxAnimatedMonthJump` months; otherwise the month changes without a page turn. With a `maxAnimatedMonthJump` of 0, even a one-month move changes without a page turn. |
| `directJump` | One page turn from the current month to the target, whatever the distance. Ignores `maxAnimatedMonthJump`. |

A sequential navigation divides `animationDuration` equally among its page turns. A change to any animation setting during a navigation applies from the next one.

### First Day of Week

```dart
// Start weeks on Monday
FlipCalendar(
  controller: controller,
  firstDayOfWeek: DateTime.monday,
  dayBuilder: dayBuilder,
)

// Start weeks on Sunday (default)
FlipCalendar(
  controller: controller,
  firstDayOfWeek: DateTime.sunday,
  dayBuilder: dayBuilder,
)
```

The weekday header row rotates to match.

### Haptic Feedback

The calendar calls `onHapticFeedback` for one event: a swipe that cannot land (see [Swipes](#swipes)). You implement the actual feedback:

```dart
FlipCalendar(
  controller: controller,
  onHapticFeedback: (type) {
    switch (type) {
      case CalendarHapticType.navigationRestricted:
        HapticFeedback.heavyImpact();
    }
  },
  dayBuilder: dayBuilder,
)
```

(`HapticFeedback` comes from `package:flutter/services.dart`.)

### Disabling Animation and Gestures

Animations are a controller setting, and gestures a calendar setting:

```dart
// No page turns: every navigation, swipes included, changes the month at once
controller.animationsEnabled = false;

// No swipes; programmatic navigation still works
FlipCalendar(
  controller: controller,
  gesturesEnabled: false,
  dayBuilder: dayBuilder,
)
```

Swipes work whether or not animations are enabled. To have no swipes when animations are off, set `gesturesEnabled` from the same setting.

## Customization

### CalendarStyle

Customize the visual appearance with `CalendarStyle`:

```dart
FlipCalendar(
  controller: controller,
  style: CalendarStyle(
    // Background
    calendarBackground: Colors.white,
    padding: const EdgeInsets.all(8),
    borderRadius: BorderRadius.circular(12),

    // Grid
    gridLineColor: Colors.grey[300]!,
    gridLineWidth: 1.0,

    // Weekday header
    weekdayHeaderBackground: Colors.grey[100]!,
    weekdayHeaderTextColor: Colors.black87,
    weekdayHeaderHeight: 40.0,
    weekdayNames: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],

    // Today indicator
    todayBorderColor: Colors.blue,
    todayBorderWidth: 2.0,

    // Selection
    selectedDayBackground: Colors.blue.withValues(alpha: 0.1),

    // Animation
    animationDuration: const Duration(milliseconds: 650),
    animationCurve: Curves.decelerate,
    pageTurnStyle: const PageTurnStyle(shadowOpacity: 0.8, curlIntensity: 1.2),

    // Gestures
    flickDistanceThreshold: 0.05,
    dragProgressThreshold: 0.3,
  ),
  dayBuilder: dayBuilder,
)
```

### Theme Presets

```dart
// Light theme (same as the default style)
FlipCalendar(
  controller: controller,
  style: CalendarStyle.light(),
  dayBuilder: dayBuilder,
)

// Dark theme
FlipCalendar(
  controller: controller,
  style: CalendarStyle.dark(),
  dayBuilder: dayBuilder,
)
```

`CalendarStyle.dark()` is the default style with nine dark colours: `calendarBackground`, `gridLineColor`, `weekdayHeaderBackground`, `weekdayHeaderTextColor`, `dayTextColor`, `disabledDayTextColor`, `todayBorderColor`, `selectedDayBackground` and `disabledDateBackground`.

### Using copyWith

`copyWith` replaces fields supplied with a non-null value. Omitted arguments and null keep the existing field, including `weekdayTextStyle`:

```dart
final customStyle = CalendarStyle.dark().copyWith(
  borderRadius: BorderRadius.circular(16),
  animationDuration: const Duration(milliseconds: 800),
  todayBorderColor: Colors.amber,
);
```

Styles compare by value: two styles with equal fields are equal.

### Style Properties

Fields with a rule are checked when a calendar builds with the style; see [Validation](#validation).

#### Background & Layout

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `calendarBackground` | `Color` | `Color(0xFFFFFFFF)` | Background of each page, behind the weekday header and the grid |
| `padding` | `EdgeInsets` | `EdgeInsets.zero` | Padding inside the background, around the header and the grid. Every side finite and not negative |
| `borderRadius` | `BorderRadius` | `BorderRadius.zero` | Rounds the page's corners by clipping it. Every radius finite and not negative |

#### Grid

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `gridLineColor` | `Color` | `Color(0xFFE0E0E0)` | Color of the grid lines and the weekday header's lines |
| `gridLineWidth` | `double` | `1.0` | Width of those lines; 0 draws no line. Finite and not negative |

Every day cell has the same size.

#### Weekday Header

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `weekdayHeaderBackground` | `Color` | `Color(0xFFF5F5F5)` | Background of the header row |
| `weekdayHeaderTextColor` | `Color` | `Color(0xDD000000)` | Text color of the names in the default text style |
| `weekdayHeaderHeight` | `double` | `40.0` | Height of the header row, limited by the available height inside padding. Finite and not negative |
| `weekdayTextStyle` | `TextStyle?` | `null` | Text style of the names. When set, it replaces the whole default style (weight 500, size 14, `weekdayHeaderTextColor`) |
| `weekdayNames` | `List<String>` | `['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']` | Weekday names starting from Sunday, rotated to `firstDayOfWeek`. Exactly 7 names |

#### Day Cells

The calendar does not draw with these fields; a day builder can read them from the style you pass.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `dayTextColor` | `Color` | `Color(0xDD000000)` | Text color for day numbers |
| `disabledDayTextColor` | `Color` | `Color(0xFF9E9E9E)` | Text color for disabled days |
| `dayTextSize` | `double` | `16.0` | Font size for day numbers. Finite and not negative |

#### Today Indicator

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `todayBorderColor` | `Color` | `Color(0xFF2196F3)` | Border color for today's cell |
| `todayBorderWidth` | `double` | `2.0` | Border width for today's cell; 0 draws no border. Finite and not negative |
| `todayBorderRadius` | `BorderRadius` | `BorderRadius.all(Radius.circular(4))` | Border radius for today's cell. Every radius finite and not negative |
| `todayMargin` | `EdgeInsets` | `EdgeInsets.all(2)` | Margin around today's cell content. Every side finite and not negative |

#### Selection & Disabled

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `selectedDayBackground` | `Color` | `Color(0x1A2196F3)` | Background for the selected day. A selected day that is disabled gets `disabledDateBackground` instead |
| `disabledDateBackground` | `Color` | `Color(0x1A9E9E9E)` | Background for disabled days |

#### Animation

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `animationDuration` | `Duration` | `Duration(milliseconds: 650)` | Duration of a page turn. A navigation that turns several pages divides it equally among them. Not negative |
| `animationCurve` | `Curve` | `Curves.decelerate` | Curve of the part of a page turn that runs by itself: each turn of a navigation, and a swipe's turn after release. While a swipe is dragged, the page follows the finger linearly |
| `pageTurnStyle` | `PageTurnStyle` | `PageTurnStyle()` | Style for the page curl effect |

#### Gestures

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `flickDistanceThreshold` | `double` | `0.05` | With `flickMaxDuration`, sets the flick speed: this fraction of the calendar's size along the swipe axis per `flickMaxDuration`. Finite and greater than 0 |
| `flickMaxDuration` | `Duration` | `Duration(milliseconds: 500)` | With `flickDistanceThreshold`, sets the flick speed. Greater than zero |
| `dragBoxSizePercentage` | `double` | `0.7` | The fraction of the calendar's size along the swipe axis that a drag covers to turn the page all the way. Finite and greater than 0 |
| `dragProgressThreshold` | `double` | `0.3` | How far the page must be turned for a release that is not a flick to complete the swipe. Greater than 0 and at most 1 |

## Validation

Invalid values throw in all builds, with an error that names the value:

| Value | Checked | Rule | Error |
|-------|---------|------|-------|
| `initialMonth` | `CalendarController()` | The month supports a complete grid and has an allowed day | `ArgumentError` |
| `minDate`, `maxDate` | `CalendarController()`, `setBounds` | `minDate` is not after `maxDate` today, and both resolve to dates `DateTime` supports | `ArgumentError` |
| `maxAnimatedMonthJump` | `CalendarController()`, setter | Not negative | `RangeError` |
| `goToYearMonth(year, month)` | Call | `month` from 1 to 12, and a month `DateTime` supports | `RangeError` |
| `firstDayOfWeek` | `FlipCalendar` build, `MonthGrid.forMonth` | From `DateTime.monday` (1) to `DateTime.sunday` (7) | `RangeError` |
| The style fields with a rule (see [Style Properties](#style-properties)) | `FlipCalendar` build | As listed | `ArgumentError` (`RangeError` for numbers) |

The calendar checks its inputs every time it builds, so a value that becomes invalid is caught when it changes; a swipe in progress then turns back without moving.

If capturing a page for a page turn throws, the error is reported through `FlutterError.reportError` and the page turn does not happen: a navigation changes the month without it, and a swipe ends without moving.

## Building a Header

The calendar renders the weekday header and the day grid; titles and navigation buttons are yours. Here's a typical pattern, with a header that rebuilds when the controller changes and disables its buttons while a navigation is in progress:

```dart
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _controller = CalendarController();
  DateTime? _selectedDate;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom header
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final month = _controller.currentMonth;
            final busy = _controller.isNavigating;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: busy ? null : _controller.previousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${_monthNames[month.month - 1]} ${month.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : _controller.nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            );
          },
        ),

        // Calendar
        Expanded(
          child: FlipCalendar(
            controller: _controller,
            selectedDate: _selectedDate,
            onDayTap: (date) => setState(() => _selectedDate = date),
            dayBuilder: (context, data) {
              return Center(child: Text(data.date.day.toString()));
            },
          ),
        ),
      ],
    );
  }
}
```

Because `currentMonth` changes when a navigation is accepted, the title shows the new month while the pages turn to it.

## API Reference

### FlipCalendar

The calendar widget.

```dart
const FlipCalendar({
  required CalendarController controller,
  required Widget Function(BuildContext, CalendarDayData) dayBuilder,
  DateTime? selectedDate,
  void Function(DateTime)? onDayTap,
  void Function(CalendarHapticType)? onHapticFeedback,
  CalendarStyle style = const CalendarStyle(),
  int firstDayOfWeek = DateTime.sunday,
  PageTurnEdge boundEdge = PageTurnEdge.top,
  bool gesturesEnabled = true,
  Key? key,
})
```

### CalendarController

Navigation state manager. Extends `ChangeNotifier`.

```dart
CalendarController({
  DateTime? initialMonth,
  ValueListenable<DateTime>? clock,
  DateConstraint? minDate,
  DateConstraint? maxDate,
  bool animationsEnabled = true,
  int maxAnimatedMonthJump = 6,
  MultiMonthAnimationMode multiMonthAnimationMode =
      MultiMonthAnimationMode.sequential,
})
```

| Property/Method | Description |
|----------------|-------------|
| `currentMonth` | The first day of the month the calendars rest on; set when a navigation is accepted |
| `today` | Today's date, from the clock or the device clock |
| `minDate` / `maxDate` | The bounds; set with `setBounds` |
| `setBounds(min, max)` | Replaces both bounds |
| `animationsEnabled` | Whether navigations animate |
| `maxAnimatedMonthJump` | The longest move `sequential` mode animates |
| `multiMonthAnimationMode` | How a navigation turns its pages |
| `isNavigating` | Whether a navigation is in progress; requests are ignored while it is |
| `isDateAllowed(date)` | Whether the day lies within the bounds |
| `canGoTo(month)` | Whether the month has an allowed day |
| `firstAllowedMonth` / `lastAllowedMonth` | The months of the bounds today, or null for an open side |
| `monthsOnWayTo(month)` | The months a navigation to `month` would show |
| `whenAtRest()` | Completes when no navigation is in progress |
| `whenShown()` | Completes once a calendar using the controller is on screen |
| `nextMonth()` / `previousMonth()` | Navigate one month |
| `goToMonth(DateTime)` | Navigate to a month |
| `goToToday()` | Navigate to today's month |
| `goToYearMonth(int, int)` | Navigate to a month of a year |

### CalendarDayData

Data object passed to the day builder. Compares by value.

| Property | Type | Description |
|----------|------|-------------|
| `date` | `DateTime` | The date this cell represents |
| `isCurrentMonth` | `bool` | Whether the date is in the page's month |
| `isToday` | `bool` | Whether the date is the controller's today |
| `isSelected` | `bool` | Whether the date is `selectedDate`'s day |
| `isFutureDate` | `bool` | Whether the date is after today |
| `isEnabled` | `bool` | Whether the date is within the bounds |
| `row` | `int` | Row index in the grid (0-based) |
| `column` | `int` | Column index in the grid (0-based) |

### DateConstraint

A date boundary: a rule that the controller resolves against its today.

| Factory | Description |
|---------|-------------|
| `DateConstraint.fixed(DateTime)` | A fixed day |
| `DateConstraint.today()` | Today; equal to `DateConstraint.relative()` |
| `DateConstraint.relative({years, months, days})` | An offset from today, with month ends capped |

`resolve(today)` returns the date a constraint stands for on a given day.

### MultiMonthAnimationMode

| Value | Description |
|-------|-------------|
| `sequential` | One page turn per month moved, up to `maxAnimatedMonthJump` months |
| `directJump` | One page turn from the current month to the target |

### CalendarHapticType

| Value | Description |
|-------|-------------|
| `navigationRestricted` | A swipe started toward a month it cannot reach |

### CalendarStyle

Configuration class for visual styling. See [Customization](#customization) for all properties.

### MonthGrid

Utility class for computing the grid layout of a month. Useful for building custom overlays or layouts on top of the calendar.

```dart
final grid = MonthGrid.forMonth(
  DateTime(2025, 6, 1),
  firstDayOfWeek: DateTime.monday,
);

debugPrint('${grid.rows}');         // 4, 5 or 6
debugPrint('${grid.start}');        // First date shown in the grid
debugPrint('${grid.dateAt(0, 0)}'); // Date at row 0, column 0
debugPrint('${grid.totalCells}');   // rows * 7
```

`dateAt` throws a `RangeError` for a row outside 0 to `rows` − 1 or a column outside 0 to 6.

## Best Practices

### Controller Lifecycle

Always dispose the controller when the parent widget is disposed:

```dart
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

A clock you pass to the controller must outlive it: dispose the clock after the controller.

### Performance Tips

- Use `CalendarStyle.pageTurnStyle` to lower `segments` (e.g., 50–80) on lower-end devices
- A sequential navigation turns one page per month; for long moves, `directJump` turns one page instead. Beyond `maxAnimatedMonthJump`, `sequential` turns no page at all

### Sizing

The calendar fills the space it is given, which must be bounded in both directions: inside a scrollable, give it a size along the scroll axis. Wrap it in a `SizedBox` or use `Expanded` to control its size:

```dart
SizedBox(
  height: 400,
  child: FlipCalendar(
    controller: controller,
    dayBuilder: (context, data) => Center(
      child: Text(data.date.day.toString()),
    ),
  ),
)
```

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests on [GitHub](https://github.com/resengi/flip_calendar).
