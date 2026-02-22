import 'package:flutter/material.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

import '../animation/flip_calendar_wrapper.dart';
import '../animation/multi_month_animation_mode.dart';
import '../style/calendar_haptic_type.dart';
import '../style/calendar_style.dart';
import '../utils/date_constraint.dart';
import '../utils/date_utils.dart';
import 'calendar_controller.dart';
import 'calendar_day_data.dart';
import 'calendar_grid.dart';

/// A customizable month calendar widget with page-turn animations
/// and swipe gesture navigation.
///
/// All state (current month, selected date) is managed externally via
/// [CalendarController] and props. Day cell rendering is fully customizable
/// via [dayBuilder].
///
/// ```dart
/// final controller = CalendarController(initialMonth: DateTime.now());
///
/// FlipCalendar(
///   controller: controller,
///   selectedDate: _selectedDate,
///   onDayTap: (date) => setState(() => _selectedDate = date),
///   dayBuilder: (context, data) {
///     return Center(
///       child: Text(
///         data.date.day.toString(),
///         style: TextStyle(
///           color: data.isEnabled ? Colors.black : Colors.grey,
///         ),
///       ),
///     );
///   },
/// )
/// ```
class FlipCalendar extends StatefulWidget {
  const FlipCalendar({
    required this.controller,
    required this.dayBuilder,
    this.selectedDate,
    this.onDayTap,
    this.onHapticFeedback,
    this.style = const CalendarStyle(),
    this.firstDayOfWeek = DateTime.sunday,
    this.minDate,
    this.maxDate,
    this.boundEdge = PageTurnEdge.top,
    this.animationsEnabled = true,
    this.gesturesEnabled = true,
    this.maxAnimatedMonthJump = 6,
    this.multiMonthAnimationMode = MultiMonthAnimationMode.sequential,
    super.key,
  }) : assert(
         firstDayOfWeek >= DateTime.monday && firstDayOfWeek <= DateTime.sunday,
         'firstDayOfWeek must be between DateTime.monday (1) '
         'and DateTime.sunday (7)',
       );

  /// Controller for managing the displayed month.
  final CalendarController controller;

  /// Builder for each day cell. Receives [CalendarDayData] with all
  /// information needed to render the cell.
  final Widget Function(BuildContext context, CalendarDayData data) dayBuilder;

  /// The currently selected date (matching cell gets `isSelected: true`).
  final DateTime? selectedDate;

  /// Called when an enabled day cell is tapped.
  final void Function(DateTime date)? onDayTap;

  /// Called for haptic feedback events (consumer implements actual haptics).
  final void Function(CalendarHapticType type)? onHapticFeedback;

  /// Style configuration for the calendar.
  final CalendarStyle style;

  /// First day of the week ([DateTime.monday] through [DateTime.sunday]).
  final int firstDayOfWeek;

  /// Minimum selectable/navigable date boundary.
  final DateConstraint? minDate;

  /// Maximum selectable/navigable date boundary.
  final DateConstraint? maxDate;

  /// Edge where calendar pages are bound (determines gesture direction).
  final PageTurnEdge boundEdge;

  /// Whether page-turn animations are enabled.
  final bool animationsEnabled;

  /// Whether swipe gestures are enabled for navigation.
  final bool gesturesEnabled;

  /// Max months to animate in [MultiMonthAnimationMode.sequential] mode.
  final int maxAnimatedMonthJump;

  /// Animation strategy for multi-month jumps.
  final MultiMonthAnimationMode multiMonthAnimationMode;

  @override
  State<FlipCalendar> createState() => _FlipCalendarState();
}

class _FlipCalendarState extends State<FlipCalendar> {
  /// Tracks last known month to filter out isAnimating-only notifications.
  DateTime? _lastKnownMonth;

  @override
  void initState() {
    super.initState();
    _lastKnownMonth = widget.controller.currentMonth;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(FlipCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _lastKnownMonth = widget.controller.currentMonth;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// Only rebuilds when the displayed month actually changes —
  /// NOT when isAnimating changes. This prevents passing a new child
  /// to the wrapper mid-animation.
  void _onControllerChanged() {
    final current = widget.controller.currentMonth;
    if (_lastKnownMonth == null ||
        !CalendarDateUtils.isSameMonth(current, _lastKnownMonth!)) {
      _lastKnownMonth = current;
      setState(() {});
    }
  }

  void _onAnimationStateChanged(bool isAnimating) {
    widget.controller.setAnimating(isAnimating);
  }

  void _onMonthChangedFromGesture(DateTime newMonth) {
    widget.controller.goToMonth(newMonth);
  }

  Widget _buildCalendarForMonth(
    DateTime month, {
    required DateTime? resolvedMinDate,
    required DateTime? resolvedMaxDate,
  }) {
    return CalendarGrid(
      currentMonth: month,
      selectedDate: widget.selectedDate,
      minDate: resolvedMinDate,
      maxDate: resolvedMaxDate,
      firstDayOfWeek: widget.firstDayOfWeek,
      style: widget.style,
      dayBuilder: widget.dayBuilder,
      onDayTap: widget.onDayTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Resolve date constraints once per build
    final resolvedMinDate = widget.minDate?.resolve();
    final resolvedMaxDate = widget.maxDate?.resolve();

    assert(
      resolvedMinDate == null ||
          resolvedMaxDate == null ||
          !resolvedMinDate.isAfter(resolvedMaxDate),
      'minDate ($resolvedMinDate) cannot be after maxDate ($resolvedMaxDate)',
    );

    // Clamp current month to valid range
    final rawMonth = widget.controller.currentMonth;
    final currentMonth = CalendarDateUtils.clampMonth(
      rawMonth,
      minDate: resolvedMinDate,
      maxDate: resolvedMaxDate,
    );

    // If clamped, update controller after this frame
    if (!CalendarDateUtils.isSameMonth(rawMonth, currentMonth)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.goToMonth(currentMonth);
      });
    }

    final calendarGrid = _buildCalendarForMonth(
      currentMonth,
      resolvedMinDate: resolvedMinDate,
      resolvedMaxDate: resolvedMaxDate,
    );

    // No animation/gesture support — just the grid
    if (!widget.animationsEnabled && !widget.gesturesEnabled) {
      return calendarGrid;
    }

    return FlipCalendarWrapper(
      currentMonth: currentMonth,
      onMonthChanged: _onMonthChangedFromGesture,
      style: widget.style,
      boundEdge: widget.boundEdge,
      minDate: resolvedMinDate,
      maxDate: resolvedMaxDate,
      maxAnimatedMonthJump: widget.maxAnimatedMonthJump,
      multiMonthAnimationMode: widget.multiMonthAnimationMode,
      animationsEnabled: widget.animationsEnabled,
      gesturesEnabled: widget.gesturesEnabled,
      buildCalendarForMonth: (month) => _buildCalendarForMonth(
        month,
        resolvedMinDate: resolvedMinDate,
        resolvedMaxDate: resolvedMaxDate,
      ),
      onHapticFeedback: widget.onHapticFeedback,
      onAnimationStateChanged: _onAnimationStateChanged,
      child: calendarGrid,
    );
  }
}
