import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../style/calendar_style.dart';
import '../utils/date_utils.dart';
import '../utils/month_grid.dart';
import 'calendar_day_data.dart';

/// The weekday header and the day cells for one month.
///
/// Taps on enabled days call [onDayTap]; the grid has no animation or swipe
/// logic.
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    required this.month,
    required this.today,
    required this.selectedDate,
    required this.resolvedMinDate,
    required this.resolvedMaxDate,
    required this.firstDayOfWeek,
    required this.style,
    required this.dayBuilder,
    required this.onDayTap,
    super.key,
  });

  /// The month this page draws. During a page turn or a swipe it can differ
  /// from the controller's current month.
  final DateTime month;

  /// Today's date, the same for every cell of one build.
  final DateTime today;

  /// The selected date, or null if no date is selected.
  final DateTime? selectedDate;

  /// The controller's lower bound resolved against [today], or null if there
  /// is none. Days before it are disabled.
  final DateTime? resolvedMinDate;

  /// The controller's upper bound resolved against [today], or null if there
  /// is none. Days after it are disabled.
  final DateTime? resolvedMaxDate;

  /// The weekday of the first column, from [DateTime.monday] to
  /// [DateTime.sunday].
  final int firstDayOfWeek;

  /// The style the header, the grid lines and the cells are drawn with.
  final CalendarStyle style;

  /// Builds the content of each day cell.
  final Widget Function(BuildContext context, CalendarDayData data) dayBuilder;

  /// Called with a day's date when an enabled day is tapped. When null, no
  /// day responds to taps.
  final void Function(DateTime date)? onDayTap;

  /// The weekday names in display order, starting from [firstDayOfWeek].
  ///
  /// [CalendarStyle.weekdayNames] starts from Sunday.
  List<String> get _rotatedWeekdayNames {
    final names = style.weekdayNames;
    final startIndex = weekdayOffset(firstDayOfWeek, DateTime.sunday);
    return [...names.sublist(startIndex), ...names.sublist(0, startIndex)];
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: style.borderRadius,
      child: ColoredBox(
        color: style.calendarBackground,
        child: Padding(
          padding: style.padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  _WeekdayHeader(
                    style: style,
                    weekdayNames: _rotatedWeekdayNames,
                    height: math.min(
                      style.weekdayHeaderHeight,
                      constraints.maxHeight,
                    ),
                  ),
                  // Each cell draws its own right and bottom line, so the
                  // frame draws only the left one.
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(left: _gridLine(style)),
                      ),
                      child: _buildGrid(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final grid = MonthGrid.forMonth(month, firstDayOfWeek: firstDayOfWeek);

    return Column(
      children: List.generate(grid.rows, (row) {
        return Expanded(
          child: Row(
            children: List.generate(DateTime.daysPerWeek, (col) {
              return Expanded(
                child: _buildCell(
                  date: grid.dateAt(row, col),
                  row: row,
                  column: col,
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildCell({
    required DateTime date,
    required int row,
    required int column,
  }) {
    final isCurrentMonth = isSameMonth(date, month);
    final isToday = isSameDay(date, today);
    final isSelected = selectedDate != null && isSameDay(date, selectedDate!);
    final isFuture = isFutureDate(date, today);
    final isEnabled = isDateSelectable(
      date,
      minDate: resolvedMinDate,
      maxDate: resolvedMaxDate,
    );

    final dayData = CalendarDayData(
      date: date,
      isCurrentMonth: isCurrentMonth,
      isToday: isToday,
      isSelected: isSelected,
      isFutureDate: isFuture,
      isEnabled: isEnabled,
      row: row,
      column: column,
    );

    final line = _gridLine(style);
    return Container(
      decoration: BoxDecoration(
        border: Border(right: line, bottom: line),
      ),
      child: _DayCell(
        dayData: dayData,
        style: style,
        onTap: (isEnabled && onDayTap != null) ? () => onDayTap!(date) : null,
        child: Builder(builder: (context) => dayBuilder(context, dayData)),
      ),
    );
  }
}

/// A grid line in [style]'s color and width, or no line for a width of 0
/// (Flutter draws a side of width 0 as a hairline).
BorderSide _gridLine(CalendarStyle style) {
  if (style.gridLineWidth == 0) return BorderSide.none;
  return BorderSide(color: style.gridLineColor, width: style.gridLineWidth);
}

/// Displays the weekday names header row above the calendar grid.
class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({
    required this.style,
    required this.weekdayNames,
    required this.height,
  });

  final CalendarStyle style;
  final double height;

  /// Weekday names to display (already rotated for firstDayOfWeek).
  final List<String> weekdayNames;

  @override
  Widget build(BuildContext context) {
    final line = _gridLine(style);
    // Each name draws its own right line, as each day cell does, so the
    // names line up with the day columns.
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: style.weekdayHeaderBackground,
        border: Border(left: line, top: line, bottom: line),
      ),
      child: Row(
        children: List.generate(DateTime.daysPerWeek, (index) {
          return Expanded(
            child: Container(
              decoration: BoxDecoration(border: Border(right: line)),
              child: Center(
                child: Text(
                  weekdayNames[index],
                  style:
                      style.weekdayTextStyle ??
                      TextStyle(
                        fontWeight: FontWeight.w500,
                        color: style.weekdayHeaderTextColor,
                        fontSize: 14,
                      ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// One day's cell: the host's content with today's outline and margin, the
/// selected or disabled background, and the tap on an enabled day.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayData,
    required this.style,
    required this.child,
    this.onTap,
  });

  final CalendarDayData dayData;
  final CalendarStyle style;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: dayData.isToday ? style.todayMargin : null,
        decoration: BoxDecoration(
          color: _backgroundColor,
          // Flutter draws a side of width 0 as a hairline.
          border: dayData.isToday && style.todayBorderWidth != 0
              ? Border.all(
                  color: style.todayBorderColor,
                  width: style.todayBorderWidth,
                )
              : null,
          borderRadius: dayData.isToday ? style.todayBorderRadius : null,
        ),
        child: child,
      ),
    );
  }

  Color? get _backgroundColor {
    if (dayData.isSelected && dayData.isEnabled) {
      return style.selectedDayBackground;
    }
    if (!dayData.isEnabled) {
      return style.disabledDateBackground;
    }
    return null;
  }
}
