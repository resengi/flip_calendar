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
- Programmatic navigation with `CalendarController`
- Date constraints (min/max) with support for fixed, relative, and dynamic dates
- Configurable bound edge (top, bottom, left, right)
- Sequential or direct-jump multi-month animation modes
- Built-in light and dark theme presets
- Haptic feedback hooks for navigation events
- Works with any first day of week (Monday, Sunday, etc.)

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

## Quick Start

```dart
import 'package:flip_calendar/flip_calendar.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

class MyCalendar extends StatefulWidget {
  @override
  State<MyCalendar> createState() => _MyCalendarState();
}

class _MyCalendarState extends State<MyCalendar> {
  final _controller = CalendarController(initialMonth: DateTime.now());
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

## Usage Guide

### CalendarController

The `CalendarController` manages the displayed month and exposes animation state. Create it once and pass it to `FlipCalendar`:

```dart
final controller = CalendarController(initialMonth: DateTime(2025, 6, 1));

// Listen for changes
controller.addListener(() {
  print('Month: ${controller.currentMonth}');
  print('Animating: ${controller.isAnimating}');
});

// Programmatic navigation
controller.nextMonth();
controller.previousMonth();
controller.goToMonth(DateTime(2025, 12, 1));
controller.goToToday();
controller.goToYearMonth(2026, 3);
```

The `isAnimating` property is useful for disabling external UI (such as header navigation buttons) while a page-turn animation is in progress.

### Day Builder

The `dayBuilder` callback receives a `CalendarDayData` object with everything you need to render each cell:

```dart
FlipCalendar(
  controller: controller,
  dayBuilder: (context, data) {
    // data.date           — the date this cell represents
    // data.isCurrentMonth — false for overflow days from adjacent months
    // data.isToday        — whether this date is today
    // data.isSelected     — whether this date matches selectedDate
    // data.isFutureDate   — whether this date is after today
    // data.isEnabled      — whether this cell is within date bounds
    // data.row / data.column — grid position (0-based)

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

### Date Constraints

Control the navigable and selectable date range using `DateConstraint`:

```dart
// Fixed date
FlipCalendar(
  controller: controller,
  minDate: DateConstraint.fixed(DateTime(2020, 1, 1)),
  maxDate: DateConstraint.fixed(DateTime(2030, 12, 31)),
  // ...
)

// Dynamic: today recomputes each build
FlipCalendar(
  controller: controller,
  maxDate: DateConstraint.today(),
  // ...
)

// Relative: 2 years back, 1 year ahead
FlipCalendar(
  controller: controller,
  minDate: DateConstraint.relative(years: -2),
  maxDate: DateConstraint.relative(years: 1),
  // ...
)
```

When a user swipes toward a restricted month, the gesture is clamped to a small bounce and the `onHapticFeedback` callback fires with `CalendarHapticType.navigationRestricted`.

### Choosing the Bound Edge

The `boundEdge` parameter controls which edge the page curls over, and determines whether swipe gestures are vertical or horizontal:

```dart
// Top-bound (default): swipe up/down to navigate
FlipCalendar(
  controller: controller,
  boundEdge: PageTurnEdge.top,
  // ...
)

// Right-bound: swipe left/right like a book
FlipCalendar(
  controller: controller,
  boundEdge: PageTurnEdge.right,
  // ...
)
```

| Edge | Gesture | Use Case |
|------|---------|----------|
| `top` | Vertical (swipe up/down) | Top-bound notepad (default) |
| `bottom` | Vertical (swipe up/down) | Wall calendar, bottom-bound pad |
| `left` | Horizontal (swipe left/right) | Right-to-left book, manga |
| `right` | Horizontal (swipe left/right) | Left-to-right book, standard Western reading |

### Multi-Month Animation Modes

When navigating multiple months at once (e.g., jumping from January to June programmatically), you can choose how the animation behaves:

```dart
// Sequential: flips through each intermediate month (default)
FlipCalendar(
  controller: controller,
  multiMonthAnimationMode: MultiMonthAnimationMode.sequential,
  maxAnimatedMonthJump: 6, // Skip animation beyond 6 months
  // ...
)

// Direct jump: single flip from start to end month
FlipCalendar(
  controller: controller,
  multiMonthAnimationMode: MultiMonthAnimationMode.directJump,
  // ...
)
```

| Mode | Behavior |
|------|----------|
| `sequential` | Flips through each month in sequence. Skips animation if jump exceeds `maxAnimatedMonthJump`. |
| `directJump` | Single page flip directly from origin to destination, regardless of distance. |

### First Day of Week

```dart
// Start weeks on Monday
FlipCalendar(
  controller: controller,
  firstDayOfWeek: DateTime.monday,
  // ...
)

// Start weeks on Sunday (default)
FlipCalendar(
  controller: controller,
  firstDayOfWeek: DateTime.sunday,
  // ...
)
```

The weekday header row automatically rotates to match.

### Haptic Feedback

The calendar exposes haptic events via a callback — you implement the actual feedback:

```dart
import 'package:flutter/services.dart';

FlipCalendar(
  controller: controller,
  onHapticFeedback: (type) {
    switch (type) {
      case CalendarHapticType.navigationRestricted:
        HapticFeedback.heavyImpact();
    }
  },
  // ...
)
```

### Disabling Animation and Gestures

```dart
// Static calendar with no animations or gestures
FlipCalendar(
  controller: controller,
  animationsEnabled: false,
  gesturesEnabled: false,
  // ...
)

// Animated programmatic navigation, but no swipe gestures
FlipCalendar(
  controller: controller,
  animationsEnabled: true,
  gesturesEnabled: false,
  // ...
)
```

## Customization

### CalendarStyle

Customize the visual appearance with `CalendarStyle`:

```dart
FlipCalendar(
  controller: controller,
  style: CalendarStyle(
    // Background
    calendarBackground: Colors.white,
    padding: EdgeInsets.all(8),
    borderRadius: BorderRadius.circular(12),

    // Grid
    gridLineColor: Colors.grey[300]!,
    gridLineWidth: 1.0,

    // Weekday header
    weekdayHeaderBackground: Colors.grey[100]!,
    weekdayHeaderTextColor: Colors.black87,
    weekdayHeaderHeight: 40.0,
    weekdayNames: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],

    // Today indicator
    todayBorderColor: Colors.blue,
    todayBorderWidth: 2.0,

    // Selection
    selectedDayBackground: Colors.blue.withValues(alpha: 0.1),

    // Animation
    animationDuration: Duration(milliseconds: 650),
    animationCurve: Curves.decelerate,
    pageTurnStyle: PageTurnStyle(
      shadowOpacity: 0.8,
      curlIntensity: 1.2,
    ),

    // Gestures
    flickDistanceThreshold: 0.05,
    dragProgressThreshold: 0.3,
  ),
  // ...
)
```

### Theme Presets

```dart
// Light theme (same as default)
FlipCalendar(
  controller: controller,
  style: CalendarStyle.light(),
  // ...
)

// Dark theme
FlipCalendar(
  controller: controller,
  style: CalendarStyle.dark(),
  // ...
)
```

### Using copyWith

```dart
final customStyle = CalendarStyle.dark().copyWith(
  borderRadius: BorderRadius.circular(16),
  animationDuration: Duration(milliseconds: 800),
  todayBorderColor: Colors.amber,
);
```

### Style Properties

#### Background & Layout

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `calendarBackground` | `Color` | `Colors.white` | Background color of the calendar widget |
| `padding` | `EdgeInsets` | `EdgeInsets.zero` | Padding inside the calendar background |
| `borderRadius` | `BorderRadius` | `BorderRadius.zero` | Border radius for the calendar's outer edges |

#### Grid

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `gridLineColor` | `Color` | `Color(0xFFE0E0E0)` | Color of grid lines between cells |
| `gridLineWidth` | `double` | `1.0` | Width of grid lines |

#### Weekday Header

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `weekdayHeaderBackground` | `Color` | `Color(0xFFF5F5F5)` | Background color of the header row |
| `weekdayHeaderTextColor` | `Color` | `Colors.black87` | Text color for weekday names |
| `weekdayHeaderHeight` | `double` | `40.0` | Height of the header row |
| `weekdayTextStyle` | `TextStyle?` | `null` | Custom text style (overrides color/size) |
| `weekdayNames` | `List<String>` | `['Sun', 'Mon', ...]` | Weekday names starting from Sunday |

#### Day Cells

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `dayTextColor` | `Color` | `Colors.black87` | Text color for day numbers |
| `disabledDayTextColor` | `Color` | `Color(0xFF9E9E9E)` | Text color for disabled days |
| `dayTextSize` | `double` | `16.0` | Font size for day numbers |

#### Today Indicator

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `todayBorderColor` | `Color` | `Colors.blue` | Border color for today's cell |
| `todayBorderWidth` | `double` | `2.0` | Border width for today's cell |
| `todayBorderRadius` | `BorderRadius` | `Radius.circular(4)` | Border radius for today's cell |
| `todayMargin` | `EdgeInsets` | `EdgeInsets.all(2)` | Margin around today's cell |

#### Selection & Disabled

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `selectedDayBackground` | `Color` | `Colors.blue (10%)` | Background for the selected day |
| `disabledDateBackground` | `Color` | `Colors.grey (10%)` | Background for disabled dates |

#### Animation

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `animationDuration` | `Duration` | `650ms` | Duration of the page-turn animation |
| `animationCurve` | `Curve` | `Curves.decelerate` | Easing curve for animation |
| `pageTurnStyle` | `PageTurnStyle` | `PageTurnStyle()` | Style for the page curl effect |

#### Gestures

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `flickDistanceThreshold` | `double` | `0.05` | Min distance fraction for a flick |
| `flickMaxDuration` | `Duration` | `500ms` | Max duration for a flick gesture |
| `dragBoxSizePercentage` | `double` | `0.7` | Fraction of dimension = 100% progress |
| `dragProgressThreshold` | `double` | `0.3` | Min progress to complete a transition |

## Building a Header

The calendar widget renders only the grid — headers, titles, and navigation buttons are your responsibility. Here's a typical pattern:

```dart
class CalendarScreen extends StatefulWidget {
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _controller = CalendarController(initialMonth: DateTime.now());
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final month = _controller.currentMonth;
    final monthName = _monthNames[month.month - 1];

    return Column(
      children: [
        // Custom header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _controller.isAnimating
                  ? null
                  : _controller.previousMonth,
              icon: Icon(Icons.chevron_left),
            ),
            Text(
              '$monthName ${month.year}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: _controller.isAnimating
                  ? null
                  : _controller.nextMonth,
              icon: Icon(Icons.chevron_right),
            ),
          ],
        ),

        // Calendar
        Expanded(
          child: FlipCalendar(
            controller: _controller,
            selectedDate: _selectedDate,
            onDayTap: (date) => setState(() => _selectedDate = date),
            dayBuilder: (context, data) {
              return Center(
                child: Text(data.date.day.toString()),
              );
            },
          ),
        ),
      ],
    );
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
}
```

Note how `_controller.isAnimating` is used to disable the navigation buttons during animation.

## API Reference

### FlipCalendar

The main calendar widget.

```dart
const FlipCalendar({
  required CalendarController controller,
  required Widget Function(BuildContext, CalendarDayData) dayBuilder,
  DateTime? selectedDate,
  void Function(DateTime)? onDayTap,
  void Function(CalendarHapticType)? onHapticFeedback,
  CalendarStyle style = const CalendarStyle(),
  int firstDayOfWeek = DateTime.sunday,
  DateConstraint? minDate,
  DateConstraint? maxDate,
  PageTurnEdge boundEdge = PageTurnEdge.top,
  bool animationsEnabled = true,
  bool gesturesEnabled = true,
  int maxAnimatedMonthJump = 6,
  MultiMonthAnimationMode multiMonthAnimationMode = MultiMonthAnimationMode.sequential,
})
```

### CalendarController

Navigation state manager. Extends `ChangeNotifier`.

| Property/Method | Description |
|----------------|-------------|
| `currentMonth` | The currently displayed month |
| `isAnimating` | Whether a transition is in progress |
| `nextMonth()` | Navigate to the next month |
| `previousMonth()` | Navigate to the previous month |
| `goToMonth(DateTime)` | Navigate to a specific month |
| `goToToday()` | Navigate to the current month |
| `goToYearMonth(int, int)` | Navigate to a specific year and month |

### CalendarDayData

Data object passed to the day builder.

| Property | Type | Description |
|----------|------|-------------|
| `date` | `DateTime` | The date this cell represents |
| `isCurrentMonth` | `bool` | Whether the date is in the displayed month |
| `isToday` | `bool` | Whether the date is today |
| `isSelected` | `bool` | Whether the date matches `selectedDate` |
| `isFutureDate` | `bool` | Whether the date is after today |
| `isEnabled` | `bool` | Whether the date is within min/max bounds |
| `row` | `int` | Row index in the grid (0-based) |
| `column` | `int` | Column index in the grid (0-based) |

### DateConstraint

Defines a date boundary. Supports static, dynamic, and relative dates.

| Factory | Description |
|---------|-------------|
| `DateConstraint.fixed(DateTime)` | A fixed date boundary |
| `DateConstraint.today()` | Today's date, recomputed each build |
| `DateConstraint.relative({years, months, days})` | Offset from today, recomputed each build |

### MultiMonthAnimationMode

| Value | Description |
|-------|-------------|
| `sequential` | Flips through each intermediate month |
| `directJump` | Single flip from start to end month |

### CalendarHapticType

| Value | Description |
|-------|-------------|
| `navigationRestricted` | User swiped toward a restricted month |

### CalendarStyle

Configuration class for visual styling. See [Customization](#customization) for all properties.

### MonthGrid

Utility class for computing the grid layout of a month. Useful for building custom overlays or layouts on top of the calendar.

```dart
final grid = MonthGrid.forMonth(
  DateTime(2025, 6, 1),
  firstDayOfWeek: DateTime.monday,
);

print(grid.rows);            // 5 or 6
print(grid.start);           // First date shown in the grid
print(grid.dateAt(0, 0));    // Date at row 0, column 0
print(grid.totalCells);      // rows * 7
```

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

### Performance Tips

- Use `CalendarStyle.pageTurnStyle` to lower `segments` (e.g., 50–80) on lower-end devices
- Avoid rebuilding the parent widget during animations — use `_controller.isAnimating` to gate updates
- For large month jumps, `MultiMonthAnimationMode.directJump` is more performant than `sequential`

### Sizing

The calendar expands to fill available space. Wrap it in a `SizedBox` or use `Expanded` to control dimensions:

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