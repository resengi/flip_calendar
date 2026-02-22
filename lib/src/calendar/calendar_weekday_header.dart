import 'package:flutter/material.dart';

import '../style/calendar_style.dart';

/// Displays the weekday names header row above the calendar grid.
class CalendarWeekdayHeader extends StatelessWidget {
  const CalendarWeekdayHeader({
    required this.style,
    required this.weekdayNames,
    super.key,
  });

  final CalendarStyle style;

  /// Weekday names to display (already rotated for firstDayOfWeek).
  final List<String> weekdayNames;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: style.weekdayHeaderHeight,
      decoration: BoxDecoration(
        color: style.weekdayHeaderBackground,
        border: Border.all(
          color: style.gridLineColor,
          width: style.gridLineWidth,
        ),
      ),
      child: Row(
        children: List.generate(weekdayNames.length, (index) {
          final isLast = index == weekdayNames.length - 1;
          return Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: !isLast
                      ? BorderSide(
                          color: style.gridLineColor,
                          width: style.gridLineWidth,
                        )
                      : BorderSide.none,
                ),
              ),
              child: Center(
                child: Text(
                  weekdayNames[index],
                  style: style.weekdayTextStyle ??
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
