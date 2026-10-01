import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonthGrid', () {
    group('forMonth with Sunday start', () {
      test('a month starting on Sunday begins the grid on its 1st', () {
        // September 2024 starts on Sunday
        final grid = MonthGrid.forMonth(
          DateTime(2024, 9, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.start, equals(DateTime(2024, 9, 1)));
        expect(grid.rows, equals(5));
      });

      test('a month starting on Monday begins the grid the Sunday before', () {
        // July 2024 starts on Monday
        final grid = MonthGrid.forMonth(
          DateTime(2024, 7, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.start, equals(DateTime(2024, 6, 30))); // Sunday before
        expect(grid.rows, equals(5));
      });

      test('month starting on Saturday (6 rows)', () {
        // June 2024 starts on Saturday
        final grid = MonthGrid.forMonth(
          DateTime(2024, 6, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.start, equals(DateTime(2024, 5, 26)));
        expect(grid.rows, equals(6));
      });

      test('a month starting on Thursday begins the grid 4 days before', () {
        // February 2024 starts on Thursday
        final grid = MonthGrid.forMonth(
          DateTime(2024, 2, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.start, equals(DateTime(2024, 1, 28)));
        expect(grid.rows, equals(5));
      });

      test('February with 4 rows (starts Sunday, 28 days)', () {
        // February 2015 starts on Sunday, 28 days = exactly 4 rows
        final grid = MonthGrid.forMonth(
          DateTime(2015, 2, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.start, equals(DateTime(2015, 2, 1)));
        expect(grid.rows, equals(4));
      });

      test('a 31st day adds a row: March 2024 has 6 rows', () {
        // March 2024 starts on Friday; 30 days would fill exactly 5 rows.
        final grid = MonthGrid.forMonth(
          DateTime(2024, 3, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.start, equals(DateTime(2024, 2, 25)));
        expect(grid.rows, equals(6));
      });

      test('January 2025 begins the grid in December 2024', () {
        final grid = MonthGrid.forMonth(
          DateTime(2025, 1, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.start, equals(DateTime(2024, 12, 29)));
      });

      test('a leap day adds a row: February 2004 has 5 rows', () {
        // February 2004 starts on Sunday; 28 days would fill exactly 4 rows.
        final grid = MonthGrid.forMonth(
          DateTime(2004, 2, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.start, equals(DateTime(2004, 2, 1)));
        expect(grid.rows, equals(5));
      });
    });

    group('forMonth with Monday start', () {
      test('a month starting on Monday begins the grid on its 1st', () {
        // July 2024 starts on Monday
        final grid = MonthGrid.forMonth(
          DateTime(2024, 7, 1),
          firstDayOfWeek: DateTime.monday,
        );
        expect(grid.start, equals(DateTime(2024, 7, 1)));
        expect(grid.rows, equals(5));
      });

      test('month starting on Sunday (6 rows)', () {
        // September 2024 starts on Sunday
        final grid = MonthGrid.forMonth(
          DateTime(2024, 9, 1),
          firstDayOfWeek: DateTime.monday,
        );
        expect(grid.start, equals(DateTime(2024, 8, 26)));
        expect(grid.rows, equals(6));
      });

      test('February 2021 fills exactly 4 rows', () {
        // February 2021 starts on Monday and has 28 days.
        final grid = MonthGrid.forMonth(
          DateTime(2021, 2, 1),
          firstDayOfWeek: DateTime.monday,
        );
        expect(grid.start, equals(DateTime(2021, 2, 1)));
        expect(grid.rows, equals(4));
      });

      test('a leap day adds a row: February 2016 has 5 rows', () {
        // February 2016 starts on Monday; 28 days would fill exactly 4 rows.
        final grid = MonthGrid.forMonth(
          DateTime(2016, 2, 1),
          firstDayOfWeek: DateTime.monday,
        );
        expect(grid.rows, equals(5));
      });
    });

    group('forMonth with every first day of the week', () {
      test('June 2024 begins on the first day of the week on or before '
          'June 1', () {
        // June 1, 2024 is a Saturday.
        final expected = {
          DateTime.monday: (DateTime(2024, 5, 27), 5),
          DateTime.tuesday: (DateTime(2024, 5, 28), 5),
          DateTime.wednesday: (DateTime(2024, 5, 29), 5),
          DateTime.thursday: (DateTime(2024, 5, 30), 5),
          DateTime.friday: (DateTime(2024, 5, 31), 5),
          DateTime.saturday: (DateTime(2024, 6, 1), 5),
          DateTime.sunday: (DateTime(2024, 5, 26), 6),
        };
        for (final MapEntry(key: firstDayOfWeek, value: (start, rows))
            in expected.entries) {
          final grid = MonthGrid.forMonth(
            DateTime(2024, 6, 1),
            firstDayOfWeek: firstDayOfWeek,
          );
          expect(
            grid.start,
            equals(start),
            reason: 'first day $firstDayOfWeek',
          );
          expect(grid.rows, equals(rows), reason: 'first day $firstDayOfWeek');
        }
      });
    });

    group('dateAt', () {
      test('the first row ends on the 7th when the month starts on the first '
          'weekday', () {
        final grid = MonthGrid.forMonth(
          DateTime(2024, 9, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.dateAt(0, 6), equals(DateTime(2024, 9, 7)));
      });

      test('the first row starts with the previous month\'s days when the '
          'month starts later in the week', () {
        // June 2024 grid starts May 26
        final grid = MonthGrid.forMonth(
          DateTime(2024, 6, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.dateAt(0, 0), equals(DateTime(2024, 5, 26)));
        expect(grid.dateAt(0, 6), equals(DateTime(2024, 6, 1)));
      });

      test('counts 7 days per row, to the last cell', () {
        // June 2024 grid starts May 26 and has 6 rows.
        final grid = MonthGrid.forMonth(
          DateTime(2024, 6, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.dateAt(2, 3), equals(DateTime(2024, 6, 12)));
        expect(grid.dateAt(5, 6), equals(DateTime(2024, 7, 6)));
      });

      test('the last cell of December 2024 is in January 2025', () {
        final grid = MonthGrid.forMonth(
          DateTime(2024, 12, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.dateAt(grid.rows - 1, 6), equals(DateTime(2025, 1, 4)));
      });

      test('a row outside the grid throws a RangeError', () {
        // September 2024, Sunday-first, has 5 rows (0 to 4).
        final grid = MonthGrid.forMonth(
          DateTime(2024, 9, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        for (final row in [-1, 5]) {
          expect(
            () => grid.dateAt(row, 0),
            throwsA(
              isA<RangeError>()
                  .having((error) => error.name, 'name', 'row')
                  .having((error) => error.start, 'start', 0)
                  .having((error) => error.end, 'end', 4),
            ),
          );
        }
      });

      test('a column outside 0 to 6 throws a RangeError', () {
        final grid = MonthGrid.forMonth(
          DateTime(2024, 9, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        for (final column in [-1, 7]) {
          expect(
            () => grid.dateAt(0, column),
            throwsA(
              isA<RangeError>()
                  .having((error) => error.name, 'name', 'column')
                  .having((error) => error.start, 'start', 0)
                  .having((error) => error.end, 'end', 6),
            ),
          );
        }
      });
    });

    group('totalCells', () {
      test('returns 28 for 4-row month', () {
        final grid = MonthGrid.forMonth(
          DateTime(2015, 2, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.totalCells, equals(28));
      });

      test('returns 42 for 6-row month', () {
        final grid = MonthGrid.forMonth(
          DateTime(2024, 6, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.totalCells, equals(42));
      });
    });

    group('the date passed to forMonth', () {
      test('any day of month produces same grid', () {
        final grid1 = MonthGrid.forMonth(
          DateTime(2024, 6, 1),
          firstDayOfWeek: DateTime.sunday,
        );
        final grid2 = MonthGrid.forMonth(
          DateTime(2024, 6, 15),
          firstDayOfWeek: DateTime.sunday,
        );
        final grid3 = MonthGrid.forMonth(
          DateTime(2024, 6, 30),
          firstDayOfWeek: DateTime.sunday,
        );

        expect(grid1.start, equals(grid2.start));
        expect(grid2.start, equals(grid3.start));
        expect(grid1.rows, equals(grid2.rows));
        expect(grid2.rows, equals(grid3.rows));
      });

      test('ignores the time of the given date', () {
        final grid = MonthGrid.forMonth(
          DateTime(2024, 6, 15, 14, 30, 45),
          firstDayOfWeek: DateTime.sunday,
        );
        expect(grid.start, equals(DateTime(2024, 5, 26)));
      });
    });

    group('constructor', () {
      test('keeps its start and rows', () {
        final grid = MonthGrid(start: DateTime(2024, 5, 26), rows: 6);
        expect(grid.start, equals(DateTime(2024, 5, 26)));
        expect(grid.rows, equals(6));
      });

      test('throws a RangeError for rows outside 4 to 6', () {
        for (final rows in [3, 7]) {
          expect(
            () => MonthGrid(start: DateTime(2024, 5, 26), rows: rows),
            throwsA(
              isA<RangeError>()
                  .having((error) => error.name, 'name', 'rows')
                  .having((error) => error.start, 'start', 4)
                  .having((error) => error.end, 'end', 6),
            ),
          );
        }
      });
    });

    group('firstDayOfWeek', () {
      test('throws a RangeError above Sunday', () {
        expect(
          () => MonthGrid.forMonth(DateTime(2024, 6, 1), firstDayOfWeek: 8),
          throwsA(
            isA<RangeError>().having(
              (error) => error.toString(),
              'message',
              'RangeError (firstDayOfWeek): Invalid value: '
                  'Not in inclusive range 1..7: 8',
            ),
          ),
        );
      });

      test('throws a RangeError below Monday', () {
        expect(
          () => MonthGrid.forMonth(DateTime(2024, 6, 1), firstDayOfWeek: 0),
          throwsA(
            isA<RangeError>().having(
              (error) => error.toString(),
              'message',
              'RangeError (firstDayOfWeek): Invalid value: '
                  'Not in inclusive range 1..7: 0',
            ),
          ),
        );
      });
    });
  });
}
