import 'package:flip_calendar/src/utils/month_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonthGrid', () {
    group('forMonth with Sunday start (default)', () {
      test('month starting on Sunday', () {
        // September 2024 starts on Sunday
        final grid = MonthGrid.forMonth(DateTime(2024, 9, 1));
        expect(grid.start, equals(DateTime(2024, 9, 1)));
        expect(grid.rows, equals(5));
      });

      test('month starting on Monday', () {
        // July 2024 starts on Monday
        final grid = MonthGrid.forMonth(DateTime(2024, 7, 1));
        expect(grid.start, equals(DateTime(2024, 6, 30))); // Sunday before
        expect(grid.rows, equals(5));
      });

      test('month starting on Saturday (6 rows)', () {
        // June 2024 starts on Saturday
        final grid = MonthGrid.forMonth(DateTime(2024, 6, 1));
        expect(grid.start, equals(DateTime(2024, 5, 26)));
        expect(grid.rows, equals(6));
      });

      test('February leap year', () {
        // February 2024 starts on Thursday
        final grid = MonthGrid.forMonth(DateTime(2024, 2, 1));
        expect(grid.start, equals(DateTime(2024, 1, 28)));
        expect(grid.rows, equals(5));
      });

      test('February with 4 rows (starts Sunday, 28 days)', () {
        // February 2015 starts on Sunday, 28 days = exactly 4 rows
        final grid = MonthGrid.forMonth(DateTime(2015, 2, 1));
        expect(grid.start, equals(DateTime(2015, 2, 1)));
        expect(grid.rows, equals(4));
      });
    });

    group('forMonth with Monday start', () {
      test('month starting on Monday', () {
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
    });

    group('dateAt', () {
      test('returns correct date for first cell', () {
        final grid = MonthGrid.forMonth(DateTime(2024, 9, 1));
        expect(grid.dateAt(0, 0), equals(DateTime(2024, 9, 1)));
      });

      test('returns correct date for last cell of first row', () {
        final grid = MonthGrid.forMonth(DateTime(2024, 9, 1));
        expect(grid.dateAt(0, 6), equals(DateTime(2024, 9, 7)));
      });

      test('returns correct date with offset', () {
        // June 2024 grid starts May 26
        final grid = MonthGrid.forMonth(DateTime(2024, 6, 1));
        expect(grid.dateAt(0, 0), equals(DateTime(2024, 5, 26)));
        expect(grid.dateAt(0, 6), equals(DateTime(2024, 6, 1)));
      });
    });

    group('totalCells', () {
      test('equals rows * 7', () {
        final grid = MonthGrid.forMonth(DateTime(2024, 9, 1));
        expect(grid.totalCells, equals(grid.rows * 7));
      });

      test('returns 28 for 4-row month', () {
        final grid = MonthGrid.forMonth(DateTime(2015, 2, 1));
        expect(grid.totalCells, equals(28));
      });

      test('returns 42 for 6-row month', () {
        final grid = MonthGrid.forMonth(DateTime(2024, 6, 1));
        expect(grid.totalCells, equals(42));
      });
    });

    group('edge cases', () {
      test('any day of month produces same grid', () {
        final grid1 = MonthGrid.forMonth(DateTime(2024, 6, 1));
        final grid2 = MonthGrid.forMonth(DateTime(2024, 6, 15));
        final grid3 = MonthGrid.forMonth(DateTime(2024, 6, 30));

        expect(grid1.start, equals(grid2.start));
        expect(grid2.start, equals(grid3.start));
        expect(grid1.rows, equals(grid2.rows));
      });

      test('handles time component in input', () {
        final grid = MonthGrid.forMonth(DateTime(2024, 6, 15, 14, 30, 45));
        expect(grid.start, equals(DateTime(2024, 5, 26)));
      });
    });
  });
}
