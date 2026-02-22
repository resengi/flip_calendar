import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateConstraint', () {
    group('fixed', () {
      test('returns exact date', () {
        final constraint = DateConstraint.fixed(DateTime(2024, 6, 15));
        expect(constraint.resolve(), equals(DateTime(2024, 6, 15)));
      });

      test('normalizes to midnight', () {
        final constraint = DateConstraint.fixed(
          DateTime(2024, 6, 15, 14, 30, 45),
        );
        final resolved = constraint.resolve();
        expect(resolved.hour, equals(0));
        expect(resolved.minute, equals(0));
        expect(resolved.second, equals(0));
      });

      test('returns same value on multiple resolves', () {
        final constraint = DateConstraint.fixed(DateTime(2024, 6, 15));
        expect(constraint.resolve(), equals(constraint.resolve()));
      });
    });

    group('today', () {
      test('resolves to current date', () {
        final constraint = DateConstraint.today();
        final resolved = constraint.resolve();
        final now = DateTime.now();

        expect(resolved.year, equals(now.year));
        expect(resolved.month, equals(now.month));
        expect(resolved.day, equals(now.day));
      });

      test('normalizes to midnight', () {
        final resolved = DateConstraint.today().resolve();
        expect(resolved.hour, equals(0));
        expect(resolved.minute, equals(0));
      });
    });

    group('relative', () {
      test('positive year offset', () {
        final resolved = DateConstraint.relative(years: 2).resolve();
        final now = DateTime.now();
        expect(resolved.year, equals(now.year + 2));
      });

      test('negative year offset', () {
        final resolved = DateConstraint.relative(years: -1).resolve();
        final now = DateTime.now();
        expect(resolved.year, equals(now.year - 1));
      });

      test('positive month offset', () {
        final resolved = DateConstraint.relative(months: 3).resolve();
        final now = DateTime.now();
        final expected = DateTime(now.year, now.month + 3, now.day);
        expect(resolved.year, equals(expected.year));
        expect(resolved.month, equals(expected.month));
      });

      test('combined offsets', () {
        final resolved = DateConstraint.relative(
          years: 1,
          months: -3,
          days: 15,
        ).resolve();
        final now = DateTime.now();
        final expected = DateTime(now.year + 1, now.month - 3, now.day + 15);
        expect(
          resolved,
          equals(DateTime(expected.year, expected.month, expected.day)),
        );
      });

      test('zero offsets equals today', () {
        final resolved = DateConstraint.relative().resolve();
        final now = DateTime.now();
        expect(resolved, equals(DateTime(now.year, now.month, now.day)));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        final str = DateConstraint.fixed(DateTime(2024, 6, 15)).toString();
        expect(str, contains('DateConstraint'));
        expect(str, contains('2024'));
      });
    });
  });
}
