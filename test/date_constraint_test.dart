import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateConstraint', () {
    final today = DateTime(2026, 9, 28);

    group('fixed', () {
      test('resolves to its date whatever today is', () {
        final constraint = DateConstraint.fixed(DateTime(2024, 6, 15));
        expect(constraint.resolve(today), equals(DateTime(2024, 6, 15)));
        expect(
          constraint.resolve(DateTime(2020, 1, 1)),
          equals(DateTime(2024, 6, 15)),
        );
      });

      test('normalizes to midnight', () {
        final constraint = DateConstraint.fixed(
          DateTime(2024, 6, 15, 14, 30, 45),
        );
        expect(constraint.resolve(today), equals(DateTime(2024, 6, 15)));
      });
    });

    group('today', () {
      test('resolves to the given today at midnight', () {
        expect(
          DateConstraint.today().resolve(DateTime(2026, 9, 28, 10, 41)),
          equals(DateTime(2026, 9, 28)),
        );
      });
    });

    group('relative', () {
      test('two years ahead is the same day two years later', () {
        expect(
          DateConstraint.relative(years: 2).resolve(today),
          equals(DateTime(2028, 9, 28)),
        );
      });

      test('a year back is the same day a year earlier', () {
        expect(
          DateConstraint.relative(years: -1).resolve(today),
          equals(DateTime(2025, 9, 28)),
        );
      });

      test('three months ahead is the same day three months later', () {
        expect(
          DateConstraint.relative(months: 3).resolve(today),
          equals(DateTime(2026, 12, 28)),
        );
      });

      test('years, months and days are added together', () {
        expect(
          DateConstraint.relative(
            years: 1,
            months: -3,
            days: 15,
          ).resolve(today),
          equals(DateTime(2027, 7, 13)),
        );
      });

      test('negative months cross into an earlier year', () {
        expect(
          DateConstraint.relative(months: -13).resolve(DateTime(2026, 1, 15)),
          equals(DateTime(2024, 12, 15)),
        );
      });

      test('days roll into the next month and year', () {
        expect(
          DateConstraint.relative(days: 1).resolve(DateTime(2026, 12, 31)),
          equals(DateTime(2027, 1, 1)),
        );
      });

      test('negative days go back across the start of a month', () {
        expect(
          DateConstraint.relative(days: -1).resolve(DateTime(2024, 3, 1)),
          equals(DateTime(2024, 2, 29)),
        );
      });
    });

    group('range', () {
      test('a date outside DateTime\'s range throws a named error', () {
        final constraint = DateConstraint.relative(years: 300000);
        expect(
          () => constraint.resolve(today),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'constraint')
                .having(
                  (error) => error.message,
                  'message',
                  'Resolves outside the dates DateTime supports',
                )
                .having(
                  (error) => error.invalidValue,
                  'invalidValue',
                  constraint,
                ),
          ),
        );
      });
    });

    group('month-end capping', () {
      test('January 31 plus one month is February 28', () {
        expect(
          DateConstraint.relative(months: 1).resolve(DateTime(2026, 1, 31)),
          equals(DateTime(2026, 2, 28)),
        );
      });

      test('January 31 plus one month is February 29 in a leap year', () {
        expect(
          DateConstraint.relative(months: 1).resolve(DateTime(2028, 1, 31)),
          equals(DateTime(2028, 2, 29)),
        );
      });

      test('March 31 minus one month is February 28', () {
        expect(
          DateConstraint.relative(months: -1).resolve(DateTime(2026, 3, 31)),
          equals(DateTime(2026, 2, 28)),
        );
      });

      test('November 30 plus three months is February 28 of the next year', () {
        expect(
          DateConstraint.relative(months: 3).resolve(DateTime(2026, 11, 30)),
          equals(DateTime(2027, 2, 28)),
        );
      });

      test('February 29 minus one year is February 28', () {
        expect(
          DateConstraint.relative(years: -1).resolve(DateTime(2028, 2, 29)),
          equals(DateTime(2027, 2, 28)),
        );
      });

      test('days are added after the day is capped', () {
        expect(
          DateConstraint.relative(
            months: 1,
            days: 1,
          ).resolve(DateTime(2026, 1, 31)),
          equals(DateTime(2026, 3, 1)),
        );
      });
    });

    group('equality', () {
      test('fixed constraints on the same day are equal', () {
        final a = DateConstraint.fixed(DateTime(2024, 6, 15, 8));
        final b = DateConstraint.fixed(DateTime(2024, 6, 15, 20));
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('fixed constraints on different days are not equal', () {
        expect(
          DateConstraint.fixed(DateTime(2024, 6, 15)),
          isNot(equals(DateConstraint.fixed(DateTime(2024, 6, 16)))),
        );
      });

      test('relative constraints differing in one offset are not equal', () {
        final base = DateConstraint.relative(years: 1, months: 2, days: 3);
        expect(
          base,
          isNot(equals(DateConstraint.relative(years: 9, months: 2, days: 3))),
        );
        expect(
          base,
          isNot(equals(DateConstraint.relative(years: 1, months: 9, days: 3))),
        );
        expect(
          base,
          isNot(equals(DateConstraint.relative(years: 1, months: 2, days: 9))),
        );
      });

      test('relative constraints with the same offsets are equal', () {
        final a = DateConstraint.relative(months: 1);
        final b = DateConstraint.relative(months: 1);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('offsets are compared as written', () {
        expect(
          DateConstraint.relative(years: 1),
          isNot(equals(DateConstraint.relative(months: 12))),
        );
      });

      test('today equals relative with no offsets', () {
        expect(DateConstraint.today(), equals(DateConstraint.relative()));
        expect(
          DateConstraint.today().hashCode,
          equals(DateConstraint.relative().hashCode),
        );
      });

      test('a fixed constraint never equals a relative one', () {
        final fixed = DateConstraint.fixed(DateTime(2026, 9, 28));
        for (final relative in [
          DateConstraint.today(),
          DateConstraint.relative(years: 1, months: -2, days: 3),
        ]) {
          expect(fixed == relative, isFalse, reason: '$relative');
          expect(relative == fixed, isFalse, reason: '$relative');
        }
      });
    });

    group('toString', () {
      test('describes a fixed constraint by its date', () {
        expect(
          DateConstraint.fixed(DateTime(2026, 1, 5, 14, 30)).toString(),
          equals('DateConstraint.fixed(2026-01-05)'),
        );
      });

      test('describes a relative constraint by all three offsets', () {
        expect(
          DateConstraint.relative(years: -2, months: 3).toString(),
          equals('DateConstraint.relative(years: -2, months: 3, days: 0)'),
        );
      });

      test('describes no offsets as today', () {
        expect(
          DateConstraint.today().toString(),
          equals('DateConstraint.today()'),
        );
        expect(
          DateConstraint.relative().toString(),
          equals('DateConstraint.today()'),
        );
      });
    });
  });
}
