import 'package:flutter/material.dart';

import '../style/calendar_style.dart';
import '../utils/date_utils.dart';
import '../utils/month_grid.dart';
import 'calendar_day_data.dart';
import 'calendar_weekday_header.dart';

/// The calendar grid: weekday header + day cells.
///
/// This is a pure rendering widget — no animation or gesture logic.
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    required this.currentMonth,
    required this.selectedDate,
    required this.firstDayOfWeek,
    required this.style,
    required this.dayBuilder,
    required this.onDayTap,
    this.minDate,
    this.maxDate,
    super.key,
  });

  final DateTime currentMonth;
  final DateTime? selectedDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final int firstDayOfWeek;
  final CalendarStyle style;
  final Widget Function(BuildContext context, CalendarDayData data) dayBuilder;
  final void Function(DateTime date)? onDayTap;

  /// Rotates weekday names based on [firstDayOfWeek].
  List<String> _getRotatedWeekdayNames() {
    final names = style.weekdayNames;
    if (names.length != 7) return CalendarStyle.defaultWeekdayNames;

    // Sunday=7 in DateTime, index 0 in our list
    final startIndex = firstDayOfWeek == DateTime.sunday ? 0 : firstDayOfWeek;
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
          child: Column(
            children: [
              CalendarWeekdayHeader(
                style: style,
                weekdayNames: _getRotatedWeekdayNames(),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: style.gridLineColor,
                        width: style.gridLineWidth,
                      ),
                      right: BorderSide(
                        color: style.gridLineColor,
                        width: style.gridLineWidth,
                      ),
                      bottom: BorderSide(
                        color: style.gridLineColor,
                        width: style.gridLineWidth,
                      ),
                    ),
                  ),
                  child: _buildGrid(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final grid = MonthGrid.forMonth(
      currentMonth,
      firstDayOfWeek: firstDayOfWeek,
    );

    return Column(
      children: List.generate(grid.rows, (row) {
        return Expanded(
          child: Row(
            children: List.generate(7, (col) {
              final date = grid.dateAt(row, col);
              final isCurrentMonth =
                  date.month == currentMonth.month &&
                  date.year == currentMonth.year;

              return Expanded(
                child: _buildCell(
                  date: date,
                  isCurrentMonth: isCurrentMonth,
                  row: row,
                  column: col,
                  isLastColumn: col == 6,
                  isLastRow: row == grid.rows - 1,
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
    required bool isCurrentMonth,
    required int row,
    required int column,
    required bool isLastColumn,
    required bool isLastRow,
  }) {
    final isToday = CalendarDateUtils.isToday(date);
    final isSelected =
        selectedDate != null &&
        CalendarDateUtils.isSameDay(date, selectedDate!);
    final isFutureDate = CalendarDateUtils.isFutureDate(date);
    final isEnabled = CalendarDateUtils.isDateSelectable(
      date,
      minDate: minDate,
      maxDate: maxDate,
    );

    final dayData = CalendarDayData(
      date: date,
      isCurrentMonth: isCurrentMonth,
      isToday: isToday,
      isSelected: isSelected,
      isFutureDate: isFutureDate,
      isEnabled: isEnabled,
      row: row,
      column: column,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: !isLastColumn
              ? BorderSide(
                  color: style.gridLineColor,
                  width: style.gridLineWidth,
                )
              : BorderSide.none,
          bottom: !isLastRow
              ? BorderSide(
                  color: style.gridLineColor,
                  width: style.gridLineWidth,
                )
              : BorderSide.none,
        ),
      ),
      child: _DayCellWrapper(
        dayData: dayData,
        style: style,
        onTap: (isEnabled && onDayTap != null) ? () => onDayTap!(date) : null,
        child: Builder(builder: (context) => dayBuilder(context, dayData)),
      ),
    );
  }
}

/// Wrapper that handles tap and applies selection/today styling.
class _DayCellWrapper extends StatelessWidget {
  const _DayCellWrapper({
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
          color: _getBackgroundColor(),
          border: dayData.isToday
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

  Color? _getBackgroundColor() {
    if (dayData.isSelected && dayData.isEnabled) {
      return style.selectedDayBackground;
    }
    if (!dayData.isEnabled) {
      return style.disabledDateBackground;
    }
    return null;
  }
}
