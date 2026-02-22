import 'package:flip_calendar/src/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarDateUtils', () {
    group('normalizeDate', () {
      test('removes time component', () {
        final date = DateTime(2024, 6, 15, 14, 30, 45, 123);
        final normalized = CalendarDateUtils.normalizeDate(date);

        expect(normalized, equals(DateTime(2024, 6, 15)));
        expect(normalized.hour, equals(0));
        expect(normalized.minute, equals(0));
        expect(normalized.second, equals(0));
        expect(normalized.millisecond, equals(0));
      });

      test('preserves date when already normalized', () {
        final date = DateTime(2024, 6, 15);
        expect(CalendarDateUtils.normalizeDate(date), equals(date));
      });
    });

    group('isSameDay', () {
      test('returns true for same date with different times', () {
        expect(
          CalendarDateUtils.isSameDay(
            DateTime(2024, 6, 15, 10, 30),
            DateTime(2024, 6, 15, 14, 45),
          ),
          isTrue,
        );
      });

      test('returns false for different days', () {
        expect(
          CalendarDateUtils.isSameDay(
            DateTime(2024, 6, 15),
            DateTime(2024, 6, 16),
          ),
          isFalse,
        );
      });

      test('returns false for different months', () {
        expect(
          CalendarDateUtils.isSameDay(
            DateTime(2024, 6, 15),
            DateTime(2024, 7, 15),
          ),
          isFalse,
        );
      });

      test('returns false for different years', () {
        expect(
          CalendarDateUtils.isSameDay(
            DateTime(2024, 6, 15),
            DateTime(2025, 6, 15),
          ),
          isFalse,
        );
      });
    });

    group('isToday', () {
      test('returns true for today', () {
        final now = DateTime.now();
        expect(
          CalendarDateUtils.isToday(DateTime(now.year, now.month, now.day, 10)),
          isTrue,
        );
      });

      test('returns false for yesterday', () {
        final now = DateTime.now();
        expect(
          CalendarDateUtils.isToday(DateTime(now.year, now.month, now.day - 1)),
          isFalse,
        );
      });
    });

    group('isFutureDate', () {
      test('returns true for tomorrow', () {
        final now = DateTime.now();
        expect(
          CalendarDateUtils.isFutureDate(
            DateTime(now.year, now.month, now.day + 1),
          ),
          isTrue,
        );
      });

      test('returns false for today', () {
        final now = DateTime.now();
        expect(
          CalendarDateUtils.isFutureDate(
            DateTime(now.year, now.month, now.day, 23, 59),
          ),
          isFalse,
        );
      });

      test('returns false for past dates', () {
        expect(CalendarDateUtils.isFutureDate(DateTime(2020, 1, 1)), isFalse);
      });
    });

    group('isSameMonth', () {
      test('returns true for same month different days', () {
        expect(
          CalendarDateUtils.isSameMonth(
            DateTime(2024, 6, 1),
            DateTime(2024, 6, 30),
          ),
          isTrue,
        );
      });

      test('returns false for different months', () {
        expect(
          CalendarDateUtils.isSameMonth(
            DateTime(2024, 6, 15),
            DateTime(2024, 7, 15),
          ),
          isFalse,
        );
      });
    });

    group('monthsDelta', () {
      test('returns 0 for same month', () {
        expect(
          CalendarDateUtils.monthsDelta(
            DateTime(2024, 6, 1),
            DateTime(2024, 6, 30),
          ),
          equals(0),
        );
      });

      test('returns positive for future months', () {
        expect(
          CalendarDateUtils.monthsDelta(
            DateTime(2024, 1, 1),
            DateTime(2024, 6, 1),
          ),
          equals(5),
        );
      });

      test('returns negative for past months', () {
        expect(
          CalendarDateUtils.monthsDelta(
            DateTime(2024, 6, 1),
            DateTime(2024, 1, 1),
          ),
          equals(-5),
        );
      });

      test('handles year boundaries', () {
        expect(
          CalendarDateUtils.monthsDelta(
            DateTime(2024, 10, 1),
            DateTime(2025, 3, 1),
          ),
          equals(5),
        );
      });
    });

    group('isDateSelectable', () {
      test('returns true when no bounds', () {
        expect(
          CalendarDateUtils.isDateSelectable(DateTime(2024, 6, 15)),
          isTrue,
        );
      });

      test('returns true within bounds', () {
        expect(
          CalendarDateUtils.isDateSelectable(
            DateTime(2024, 6, 15),
            minDate: DateTime(2024, 1, 1),
            maxDate: DateTime(2024, 12, 31),
          ),
          isTrue,
        );
      });

      test('returns true on exact boundary', () {
        expect(
          CalendarDateUtils.isDateSelectable(
            DateTime(2024, 6, 1),
            minDate: DateTime(2024, 6, 1),
          ),
          isTrue,
        );
      });

      test('returns false before minDate', () {
        expect(
          CalendarDateUtils.isDateSelectable(
            DateTime(2024, 5, 31),
            minDate: DateTime(2024, 6, 1),
          ),
          isFalse,
        );
      });

      test('returns false after maxDate', () {
        expect(
          CalendarDateUtils.isDateSelectable(
            DateTime(2024, 7, 1),
            maxDate: DateTime(2024, 6, 30),
          ),
          isFalse,
        );
      });

      test('normalizes time component', () {
        expect(
          CalendarDateUtils.isDateSelectable(
            DateTime(2024, 6, 15, 23, 59, 59),
            minDate: DateTime(2024, 6, 15, 0, 0, 0),
            maxDate: DateTime(2024, 6, 15, 12, 0, 0),
          ),
          isTrue,
        );
      });
    });

    group('isMonthNavigable', () {
      test('returns true when no bounds', () {
        expect(
          CalendarDateUtils.isMonthNavigable(DateTime(2024, 6, 1)),
          isTrue,
        );
      });

      test('returns false when entirely before minDate', () {
        expect(
          CalendarDateUtils.isMonthNavigable(
            DateTime(2024, 5, 1),
            minDate: DateTime(2024, 6, 1),
          ),
          isFalse,
        );
      });

      test('returns false when entirely after maxDate', () {
        expect(
          CalendarDateUtils.isMonthNavigable(
            DateTime(2024, 7, 1),
            maxDate: DateTime(2024, 6, 30),
          ),
          isFalse,
        );
      });

      test('returns true when minDate is in middle of month', () {
        expect(
          CalendarDateUtils.isMonthNavigable(
            DateTime(2024, 6, 1),
            minDate: DateTime(2024, 6, 15),
          ),
          isTrue,
        );
      });
    });

    group('clampMonth', () {
      test('returns same month when no bounds', () {
        final result = CalendarDateUtils.clampMonth(DateTime(2024, 6, 1));
        expect(result.year, equals(2024));
        expect(result.month, equals(6));
      });

      test('clamps to minDate when before', () {
        final result = CalendarDateUtils.clampMonth(
          DateTime(2024, 3, 1),
          minDate: DateTime(2024, 6, 15),
        );
        expect(result.year, equals(2024));
        expect(result.month, equals(6));
      });

      test('clamps to maxDate when after', () {
        final result = CalendarDateUtils.clampMonth(
          DateTime(2024, 10, 1),
          maxDate: DateTime(2024, 6, 15),
        );
        expect(result.year, equals(2024));
        expect(result.month, equals(6));
      });

      test('normalizes day to 1', () {
        final result = CalendarDateUtils.clampMonth(DateTime(2024, 6, 15));
        expect(result.day, equals(1));
      });
    });
  });
}
