import 'package:flip_calendar/flip_calendar.dart';
import 'package:flip_calendar/src/calendar/calendar_controller.dart'
    show ControlledCalendar;
import 'package:flip_calendar/src/utils/date_utils.dart' as dates;
import 'package:flutter_test/flutter_test.dart';

class _Calendar implements ControlledCalendar {
  @override
  void checkOnScreen() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('month normalization carries positive and negative whole years', () {
    for (final month in [-25, -12, -1, 0, 1, 12, 13, 25]) {
      final normalized = dates.normalizeYearMonth(
        BigInt.from(2024),
        BigInt.from(month),
      );
      final expected = DateTime(2024, month);
      expect(normalized.year, BigInt.from(expected.year));
      expect(normalized.month, expected.month);
    }
  });

  test('civil field construction matches local Gregorian normalization', () {
    for (final year in [-3000, -401, -400, -1, 0, 1, 400, 1900, 2000, 2026]) {
      for (var month = 1; month <= 12; month++) {
        for (final day in [-400, 0, 1, 28, 31, 400]) {
          final actual = dates.localDateFromCivilFields(
            year: BigInt.from(year),
            month: month,
            day: BigInt.from(day),
          );
          expect(actual, DateTime(year, month, day));
          expect(actual.isUtc, isFalse);
        }
      }
    }
  });

  test('civil range endpoints follow local DateTime construction', () {
    for (final fields in [(-271821, 4, 20), (275760, 9, 13)]) {
      DateTime? expected;
      try {
        expected = DateTime(fields.$1, fields.$2, fields.$3);
      } on ArgumentError {
        expected = null;
      }
      DateTime construct() => dates.localDateFromCivilFields(
        year: BigInt.from(fields.$1),
        month: fields.$2,
        day: BigInt.from(fields.$3),
      );
      if (expected == null) {
        expect(construct, throwsArgumentError);
      } else {
        expect(construct(), expected);
      }
    }
    for (final fields in [(-271821, 4, 19), (275760, 9, 14)]) {
      expect(
        () => dates.localDateFromCivilFields(
          year: BigInt.from(fields.$1),
          month: fields.$2,
          day: BigInt.from(fields.$3),
        ),
        throwsArgumentError,
      );
    }
  });

  test('month lengths use Gregorian leap-year rules', () {
    expect(dates.daysInMonth(2024, 2), 29);
    expect(dates.daysInMonth(2026, 2), 28);
    expect(dates.daysInMonth(1900, 2), 28);
    expect(dates.daysInMonth(2000, 2), 29);
    expect(dates.daysInMonth(2024, 12), 31);
    expect(dates.daysInMonth(2024, 6), 30);
  });

  for (final busy in [false, true]) {
    test('far-year requests preserve controller state while busy=$busy', () {
      final controller = CalendarController(
        initialMonth: DateTime(2024, 6),
      );
      final calendar = _Calendar();
      addTearDown(controller.dispose);
      if (busy) {
        controller.calendarJoined(calendar);
        controller.nextMonth();
      }
      final month = controller.currentMonth;
      final pages = controller.calendarPages;
      var notifications = 0;
      controller.addListener(() => notifications++);
      for (final year in [500000, -500000, 300000, 1000000]) {
        expect(() => controller.goToYearMonth(year, 1), throwsRangeError);
        expect(controller.currentMonth, month);
        expect(controller.calendarPages, pages);
        expect(controller.isNavigating, busy);
        expect(notifications, 0);
      }
      if (busy) controller.calendarLeft(calendar);
    });
  }

  test('representable partial months use supported-grid landing', () {
    final controller = CalendarController(initialMonth: DateTime(2024, 6));
    addTearDown(controller.dispose);
    controller.goToYearMonth(275760, 9);
    expect(controller.currentMonth, DateTime(275760, 8));
    expect(() => controller.goToYearMonth(275760, 10), throwsRangeError);
    expect(() => controller.goToYearMonth(-271821, 4), throwsRangeError);
    controller.goToYearMonth(-271821, 5);
    expect(controller.currentMonth, DateTime(-271821, 5));
    for (final year in [-100, 0, 1, 2026]) {
      controller.goToYearMonth(year, 1);
      expect(controller.currentMonth, DateTime(year, 1));
    }
  });

  test('relative offsets preserve capping and valid cancellations', () {
    final today = DateTime(2026, 1, 31);
    final cases = <(DateConstraint, DateTime)>[
      (DateConstraint.relative(months: 1), DateTime(2026, 2, 28)),
      (DateConstraint.relative(months: 1, days: 1), DateTime(2026, 3, 1)),
      (DateConstraint.relative(years: 1000, months: -12000), today),
      (DateConstraint.relative(years: 1000, days: -365242), today),
      (
        DateConstraint.relative(years: -410000, days: 150000000),
        DateTime(2712, 2, 20),
      ),
    ];
    for (final (constraint, expected) in cases) {
      expect(constraint.resolve(today), expected);
    }
  });

  test('relative results outside the date range identify the constraint', () {
    final today = DateTime(2026, 1, 31);
    for (final constraint in [
      DateConstraint.relative(years: 500000),
      DateConstraint.relative(years: -500000),
      DateConstraint.relative(months: 6000000),
      DateConstraint.relative(months: -6000000),
      DateConstraint.relative(days: 200000000),
      DateConstraint.relative(days: -200000000),
    ]) {
      expect(
        () => constraint.resolve(today),
        throwsA(isA<ArgumentError>()
            .having((error) => error.name, 'name', 'constraint')
            .having((error) => error.invalidValue, 'invalidValue', constraint)
            .having((error) => error.message, 'message',
                'Resolves outside the dates DateTime supports')),
      );
    }
  });
}
