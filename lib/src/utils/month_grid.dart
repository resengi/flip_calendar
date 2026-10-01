import 'date_utils.dart';

/// Represents the grid layout for a month in the calendar.
///
/// Computes the starting date and number of rows needed to display a complete
/// month, including days from adjacent months to fill the grid.
class MonthGrid {
  /// Creates a MonthGrid for the given month.
  ///
  /// [month] can be any date within the target month.
  /// [firstDayOfWeek] controls which day starts each row, from
  /// [DateTime.monday] (1) to [DateTime.sunday] (7); any other value throws a
  /// [RangeError].
  factory MonthGrid.forMonth(DateTime month, {required int firstDayOfWeek}) {
    RangeError.checkValueInInterval(
      firstDayOfWeek,
      DateTime.monday,
      DateTime.sunday,
      'firstDayOfWeek',
    );
    final firstOfMonth = normalizeMonth(month);
    final lastOfMonth = lastDayOfMonth(month);

    final offset = weekdayOffset(firstOfMonth.weekday, firstDayOfWeek);
    final cellsToLastDay = offset + lastOfMonth.day;
    final rows = (cellsToLastDay / 7).ceil();

    final startDate = DateTime(
      firstOfMonth.year,
      firstOfMonth.month,
      firstOfMonth.day - offset,
    );

    return MonthGrid(start: startDate, rows: rows);
  }

  /// Creates a grid whose first cell is [start], with [rows] weeks.
  ///
  /// Throws a [RangeError] if [rows] is outside 4 to 6.
  MonthGrid({required this.start, required int rows})
    : rows = RangeError.checkValueInInterval(rows, 4, 6, 'rows');

  /// The first date displayed in the grid (may be from the previous month).
  final DateTime start;

  /// The number of rows (weeks) in this month's grid (4, 5, or 6).
  final int rows;

  /// The date in [row], from 0 to [rows] − 1, and [column], from 0 to 6.
  ///
  /// Throws a [RangeError] for a row or column outside the grid.
  DateTime dateAt(int row, int column) {
    RangeError.checkValueInInterval(row, 0, rows - 1, 'row');
    RangeError.checkValueInInterval(column, 0, 6, 'column');
    final dayOffset = row * 7 + column;
    return DateTime(start.year, start.month, start.day + dayOffset);
  }

  /// Total number of cells in the grid.
  int get totalCells => rows * 7;
}
