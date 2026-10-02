import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CalendarController controllerFor(
    DateTime month, {
    DateConstraint? minDate,
    DateConstraint? maxDate,
  }) {
    final controller = CalendarController(
      initialMonth: month,
      minDate: minDate,
      maxDate: maxDate,
      animationsEnabled: false,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  group('complete calendar months', () {
    for (final month in [DateTime(-271821, 5), DateTime(275760, 8)]) {
      for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
        test('${month.year}-${month.month} supports weekday $weekday', () {
          final controller = controllerFor(month);
          expect(controller.canGoTo(month), isTrue);
          expect(controller.currentMonth.isUtc, isFalse);
          final grid = MonthGrid.forMonth(month, firstDayOfWeek: weekday);
          DateTime? previous;
          for (var row = 0; row < grid.rows; row++) {
            for (var column = 0; column < DateTime.daysPerWeek; column++) {
              final date = grid.dateAt(row, column);
              expect(date.isUtc, isFalse);
              if (previous != null) expect(date.isAfter(previous), isTrue);
              previous = date;
            }
          }
        });
      }
    }

    test('partial endpoint months are rejected before rendering', () {
      final controller = controllerFor(DateTime(2026, 9));
      for (final month in [
        DateTime.utc(-271821, 4, 20),
        DateTime.utc(275760, 9),
      ]) {
        expect(controller.canGoTo(month), isFalse);
        expect(
          () => MonthGrid.forMonth(month, firstDayOfWeek: DateTime.sunday),
          throwsA(isA<RangeError>()),
        );
        expect(
          () => CalendarController(initialMonth: month),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('month validity is independent of an unrelated lower bound', () {
      final month = DateTime.utc(275760, 9);
      final open = controllerFor(DateTime(275760, 7));
      final bounded = controllerFor(
        DateTime(275760, 7),
        minDate: DateConstraint.fixed(DateTime(275760, 7)),
      );
      expect(open.canGoTo(month), isFalse);
      expect(bounded.canGoTo(month), isFalse);
    });

    test('requests use the nearest supported month in their direction', () {
      final lower = controllerFor(DateTime(-271821, 6));
      lower.goToMonth(DateTime.utc(-271821, 4, 20));
      expect(lower.currentMonth, DateTime(-271821, 5));
      lower.previousMonth();
      expect(lower.currentMonth, DateTime(-271821, 5));

      final upper = controllerFor(DateTime(275760, 7));
      upper.goToYearMonth(275760, 9);
      expect(upper.currentMonth, DateTime(275760, 8));
      upper.nextMonth();
      expect(upper.currentMonth, DateTime(275760, 8));
    });

    test('individual endpoint bounds need not be displayable months', () {
      final controller = controllerFor(
        DateTime(275760, 8),
        maxDate: DateConstraint.fixed(DateTime(275760, 9, 5)),
      );
      expect(controller.lastAllowedMonth, DateTime(275760, 9));
      expect(controller.canGoTo(DateTime(275760, 9)), isFalse);
      expect(controller.isDateAllowed(DateTime(275760, 9, 5)), isTrue);
      controller.nextMonth();
      expect(controller.currentMonth, DateTime(275760, 8));
    });

    test('open and crossed bounds retain their getter meanings', () {
      final clock = ValueNotifier(DateTime(2026, 9, 25));
      final controller = CalendarController(
        initialMonth: DateTime(2026, 9),
        clock: clock,
        minDate: DateConstraint.fixed(DateTime(2026, 9, 20)),
        maxDate: DateConstraint.today(),
      );
      addTearDown(() {
        controller.dispose();
        clock.dispose();
      });
      clock.value = DateTime(2026, 9, 15);
      expect(controller.canGoTo(DateTime(2026, 9)), isFalse);
      expect(controller.firstAllowedMonth, DateTime(2026, 9));
      expect(controller.lastAllowedMonth, DateTime(2026, 9));
      controller.setBounds(null, null);
      expect(controller.firstAllowedMonth, isNull);
      expect(controller.lastAllowedMonth, isNull);
    });

    test('a raw bound month without a representable first day throws', () {
      final controller = controllerFor(
        DateTime(-271821, 5),
        minDate: DateConstraint.fixed(DateTime(-271821, 4, 25)),
      );
      expect(controller.canGoTo(DateTime(-271821, 5)), isTrue);
      expect(() => controller.firstAllowedMonth, throwsA(isA<ArgumentError>()));
    });
  });

  group('relative constraint results', () {
    test('today preserves supported days in partial endpoint months', () {
      for (final date in [DateTime(-271821, 4, 25), DateTime(275760, 9, 5)]) {
        final result = DateConstraint.today().resolve(date);
        expect(result, date);
        expect(result.isUtc, isFalse);
      }
    });

    test('the final result must be representable', () {
      expect(
        () => DateConstraint.relative(days: -10).resolve(
          DateTime(-271821, 4, 25),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => DateConstraint.relative(days: 20).resolve(DateTime(275760, 9, 5)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Gregorian century rules determine the capped day', () {
      expect(
        DateConstraint.relative(months: 1).resolve(DateTime(1900, 1, 31)),
        DateTime(1900, 2, 28),
      );
      expect(
        DateConstraint.relative(months: 1).resolve(DateTime(2000, 1, 31)),
        DateTime(2000, 2, 29),
      );
      expect(
        DateConstraint.relative(months: 1, days: 1).resolve(
          DateTime(2026, 1, 31),
        ),
        DateTime(2026, 3, 1),
      );
    });

    test('signed month offsets carry through year zero', () {
      expect(
        DateConstraint.relative(months: -1).resolve(DateTime(0, 1, 31)),
        DateTime(-1, 12, 31),
      );
      expect(
        DateConstraint.relative(months: 13).resolve(DateTime(-1, 1, 31)),
        DateTime(0, 2, 29),
      );
    });
  });
}
