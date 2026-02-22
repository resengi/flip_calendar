/// Data passed to [FlipCalendar.dayBuilder] for each day cell.
class CalendarDayData {
  const CalendarDayData({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.isFutureDate,
    required this.isEnabled,
    required this.row,
    required this.column,
  });

  /// The date this cell represents.
  final DateTime date;

  /// Whether this date is in the currently displayed month.
  /// False for overflow days from adjacent months.
  final bool isCurrentMonth;

  /// Whether this date is today.
  final bool isToday;

  /// Whether this date is the currently selected date.
  final bool isSelected;

  /// Whether this date is in the future (after today).
  final bool isFutureDate;

  /// Whether this cell is enabled for interaction (within date bounds).
  final bool isEnabled;

  /// Row index in the grid (0-based).
  final int row;

  /// Column index in the grid (0-based).
  final int column;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CalendarDayData) return false;

    return other.date == date &&
        other.isCurrentMonth == isCurrentMonth &&
        other.isToday == isToday &&
        other.isSelected == isSelected &&
        other.isFutureDate == isFutureDate &&
        other.isEnabled == isEnabled &&
        other.row == row &&
        other.column == column;
  }

  @override
  int get hashCode => Object.hash(
    date,
    isCurrentMonth,
    isToday,
    isSelected,
    isFutureDate,
    isEnabled,
    row,
    column,
  );

  @override
  String toString() =>
      'CalendarDayData(date: $date, isCurrentMonth: $isCurrentMonth, '
      'isToday: $isToday, isSelected: $isSelected, '
      'isFutureDate: $isFutureDate, isEnabled: $isEnabled, '
      'row: $row, column: $column)';
}
