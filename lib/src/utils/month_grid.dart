/// Represents the grid layout for a month in the calendar.
///
/// Computes the starting date and number of rows needed to display a complete
/// month, including days from adjacent months to fill the grid.
class MonthGrid {
  /// Creates a MonthGrid for the given month.
  ///
  /// [month] can be any date within the target month.
  /// [firstDayOfWeek] controls which day starts each row
  /// (use [DateTime.monday] through [DateTime.sunday]).
  factory MonthGrid.forMonth(
    DateTime month, {
    int firstDayOfWeek = DateTime.sunday,
  }) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final lastOfMonth = DateTime(month.year, month.month + 1, 0);

    final offset = _calculateOffset(firstOfMonth.weekday, firstDayOfWeek);
    final totalCells = offset + lastOfMonth.day;
    final rows = (totalCells / 7).ceil();

    final startDate = DateTime(
      firstOfMonth.year,
      firstOfMonth.month,
      firstOfMonth.day - offset,
    );

    return MonthGrid(start: startDate, rows: rows);
  }

  /// Creates a MonthGrid with the specified start date and row count.
  const MonthGrid({required this.start, required this.rows});

  /// The first date displayed in the grid (may be from the previous month).
  final DateTime start;

  /// The number of rows (weeks) in this month's grid (4, 5, or 6).
  final int rows;

  /// Calculates the column offset for a given weekday relative to
  /// [firstDayOfWeek].
  static int _calculateOffset(int weekday, int firstDayOfWeek) {
    // DateTime.weekday: Monday=1 .. Sunday=7
    final firstDayValue = firstDayOfWeek == DateTime.sunday
        ? 7
        : firstDayOfWeek;

    int offset = weekday - firstDayValue;
    if (offset < 0) offset += 7;
    return offset;
  }

  /// Returns the date at a specific grid position.
  DateTime dateAt(int row, int column) {
    final dayOffset = row * 7 + column;
    return DateTime(start.year, start.month, start.day + dayOffset);
  }

  /// Total number of cells in the grid.
  int get totalCells => rows * 7;
}
