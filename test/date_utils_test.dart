import 'package:flip_calendar/src/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('date_utils', () {
    group('normalizeDate', () {
      test('removes time component', () {
        expect(
          normalizeDate(DateTime(2024, 6, 15, 14, 30, 45, 123, 456)),
          equals(DateTime(2024, 6, 15)),
        );
      });

      test('a UTC date gives the local date with the same fields', () {
        final normalized = normalizeDate(DateTime.utc(2024, 6, 15, 23));
        expect(normalized, equals(DateTime(2024, 6, 15)));
        expect(normalized.isUtc, isFalse);
      });
    });

    group('normalizeMonth', () {
      test('a date with a time gives the first of its month at midnight', () {
        expect(
          normalizeMonth(DateTime(2024, 6, 15, 14, 30)),
          equals(DateTime(2024, 6, 1)),
        );
      });

      test('the first of a month gives the same date', () {
        expect(
          normalizeMonth(DateTime(2024, 6, 1)),
          equals(DateTime(2024, 6, 1)),
        );
      });

      test('the last moment of a year stays in that year', () {
        expect(
          normalizeMonth(DateTime(2024, 12, 31, 23, 59, 59)),
          equals(DateTime(2024, 12, 1)),
        );
      });
    });

    group('isSameDay', () {
      test('returns true for same date with different times', () {
        expect(
          isSameDay(
            DateTime(2024, 6, 15, 10, 30),
            DateTime(2024, 6, 15, 14, 45),
          ),
          isTrue,
        );
      });

      test('returns false for different days', () {
        expect(
          isSameDay(DateTime(2024, 6, 15), DateTime(2024, 6, 16)),
          isFalse,
        );
      });

      test('returns false for different months', () {
        expect(
          isSameDay(DateTime(2024, 6, 15), DateTime(2024, 7, 15)),
          isFalse,
        );
      });

      test('returns false for different years', () {
        expect(
          isSameDay(DateTime(2024, 6, 15), DateTime(2025, 6, 15)),
          isFalse,
        );
      });
    });

    group('isFutureDate', () {
      final today = DateTime(2026, 9, 28);

      test('returns true for tomorrow', () {
        expect(isFutureDate(DateTime(2026, 9, 29), today), isTrue);
      });

      test('returns false for later the same day', () {
        expect(isFutureDate(DateTime(2026, 9, 28, 23, 59), today), isFalse);
      });

      test('returns false for past dates', () {
        expect(isFutureDate(DateTime(2020, 1, 1), today), isFalse);
      });
    });

    group('isSameMonth', () {
      test('returns true for same month different days', () {
        expect(
          isSameMonth(DateTime(2024, 6, 1), DateTime(2024, 6, 30)),
          isTrue,
        );
      });

      test('returns false for different months', () {
        expect(
          isSameMonth(DateTime(2024, 6, 15), DateTime(2024, 7, 15)),
          isFalse,
        );
      });

      test('returns false for the same month in different years', () {
        expect(
          isSameMonth(DateTime(2024, 6, 15), DateTime(2025, 6, 15)),
          isFalse,
        );
      });
    });

    group('monthsDelta', () {
      test('returns 0 for same month', () {
        expect(
          monthsDelta(DateTime(2024, 6, 1), DateTime(2024, 6, 30)),
          equals(0),
        );
      });

      test('is positive when the second month is later', () {
        expect(
          monthsDelta(DateTime(2024, 1, 1), DateTime(2024, 6, 1)),
          equals(5),
        );
      });

      test('is negative when the second month is earlier', () {
        expect(
          monthsDelta(DateTime(2024, 6, 1), DateTime(2024, 1, 1)),
          equals(-5),
        );
      });

      test('counts across a year boundary', () {
        expect(
          monthsDelta(DateTime(2024, 10, 1), DateTime(2025, 3, 1)),
          equals(5),
        );
      });

      test('counts back across a year boundary', () {
        expect(
          monthsDelta(DateTime(2025, 1, 1), DateTime(2024, 12, 1)),
          equals(-1),
        );
      });
    });

    group('isDateSelectable', () {
      test('returns true when no bounds', () {
        expect(isDateSelectable(DateTime(2024, 6, 15)), isTrue);
      });

      test('returns true within bounds', () {
        expect(
          isDateSelectable(
            DateTime(2024, 6, 15),
            minDate: DateTime(2024, 1, 1),
            maxDate: DateTime(2024, 12, 31),
          ),
          isTrue,
        );
      });

      test('includes both bounds', () {
        expect(
          isDateSelectable(DateTime(2024, 6, 1), minDate: DateTime(2024, 6, 1)),
          isTrue,
        );
        expect(
          isDateSelectable(
            DateTime(2024, 6, 30),
            maxDate: DateTime(2024, 6, 30),
          ),
          isTrue,
        );
      });

      test('returns false before minDate', () {
        expect(
          isDateSelectable(
            DateTime(2024, 5, 31),
            minDate: DateTime(2024, 6, 1),
          ),
          isFalse,
        );
      });

      test('returns false after maxDate', () {
        expect(
          isDateSelectable(
            DateTime(2024, 7, 1),
            maxDate: DateTime(2024, 6, 30),
          ),
          isFalse,
        );
      });

      test('ignores the time of the date and of the lower bound', () {
        // First the date's time is later than the upper bound's, then the
        // lower bound's time is later than the date's.
        expect(
          isDateSelectable(
            DateTime(2024, 6, 15, 23, 59, 59),
            maxDate: DateTime(2024, 6, 15, 12),
          ),
          isTrue,
        );
        expect(
          isDateSelectable(
            DateTime(2024, 6, 15),
            minDate: DateTime(2024, 6, 15, 12),
          ),
          isTrue,
        );
      });
    });

    group('weekdayOffset', () {
      test('Tuesday in a Monday-first week is column 1', () {
        expect(weekdayOffset(DateTime.tuesday, DateTime.monday), equals(1));
      });

      test('Tuesday in a Sunday-first week is column 2', () {
        expect(weekdayOffset(DateTime.tuesday, DateTime.sunday), equals(2));
      });

      test('the first day of the week is column 0', () {
        expect(weekdayOffset(DateTime.thursday, DateTime.thursday), equals(0));
      });

      test('Sunday in a Monday-first week is column 6', () {
        expect(weekdayOffset(DateTime.sunday, DateTime.monday), equals(6));
      });

      test('Saturday in a Sunday-first week is column 6', () {
        expect(weekdayOffset(DateTime.saturday, DateTime.sunday), equals(6));
      });

      test('Monday in a Sunday-first week is column 1', () {
        expect(weekdayOffset(DateTime.monday, DateTime.sunday), equals(1));
      });
    });
  });
}
