import 'dart:math' as math;

import 'date_utils.dart';

/// A constraint that defines a date boundary for the calendar: a fixed
/// date, or a date relative to today.
///
/// A constraint holds the rule, not a date: [resolve] turns it into a date
/// for a given today.
///
/// ```dart
/// // Fixed date
/// DateConstraint.fixed(DateTime(2020, 1, 1))
///
/// // Today
/// DateConstraint.today()
///
/// // Relative to today
/// DateConstraint.relative(years: -2, months: 3)
/// ```
///
/// Two fixed constraints are equal when they fall on the same day. Two
/// relative constraints are equal when their years, months and days are
/// equal, each compared on its own: `DateConstraint.relative(years: 1)` does
/// not equal `DateConstraint.relative(months: 12)`, and
/// `DateConstraint.today()` equals `DateConstraint.relative()`. A fixed
/// constraint never equals a relative one.
sealed class DateConstraint {
  /// Creates a constraint for [date]'s calendar day; its time is dropped.
  factory DateConstraint.fixed(DateTime date) {
    return _FixedDateConstraint(normalizeDate(date));
  }

  /// Creates a constraint for today's date.
  ///
  /// Equal to [DateConstraint.relative] with no offsets.
  factory DateConstraint.today() {
    return DateConstraint.relative();
  }

  /// Creates a constraint relative to today.
  ///
  /// [years] and [months] are added first, keeping today's day of the month
  /// but capping it at the last day of the resulting month; [days] are added
  /// after that. From January 31, `months: 1` gives the last day of February,
  /// and `months: 1, days: 1` gives March 1.
  ///
  /// All parameters can be positive (future) or negative (past).
  factory DateConstraint.relative({
    int years = 0,
    int months = 0,
    int days = 0,
  }) {
    return _RelativeDateConstraint(years, months, days);
  }

  const DateConstraint._();

  /// The date this constraint stands for when today is [today], as a local
  /// `DateTime(year, month, day)`.
  ///
  /// Throws an [ArgumentError] if that date is outside the range [DateTime]
  /// supports.
  DateTime resolve(DateTime today);
}

class _FixedDateConstraint extends DateConstraint {
  const _FixedDateConstraint(this.date) : super._();

  final DateTime date;

  @override
  DateTime resolve(DateTime today) => date;

  @override
  bool operator ==(Object other) {
    return other is _FixedDateConstraint && other.date == date;
  }

  @override
  int get hashCode => date.hashCode;

  @override
  String toString() => 'DateConstraint.fixed(${'$date'.split(' ').first})';
}

class _RelativeDateConstraint extends DateConstraint {
  const _RelativeDateConstraint(this.years, this.months, this.days) : super._();

  final int years;
  final int months;
  final int days;

  @override
  DateTime resolve(DateTime today) {
    try {
      final (:year, :month) = normalizeYearMonth(
        BigInt.from(today.year) + BigInt.from(years),
        BigInt.from(today.month) + BigInt.from(months),
      );
      final cappedDay = math.min(
        today.day,
        daysInMonth((year % BigInt.from(400)).toInt(), month),
      );
      return localDateFromCivilFields(
        year: year,
        month: month,
        day: BigInt.from(cappedDay) + BigInt.from(days),
      );
    } on ArgumentError {
      throw ArgumentError.value(
        this,
        'constraint',
        'Resolves outside the dates DateTime supports',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    return other is _RelativeDateConstraint &&
        other.years == years &&
        other.months == months &&
        other.days == days;
  }

  @override
  int get hashCode => Object.hash(years, months, days);

  @override
  String toString() {
    if (years == 0 && months == 0 && days == 0) {
      return 'DateConstraint.today()';
    }
    return 'DateConstraint.relative(years: $years, months: $months, '
        'days: $days)';
  }
}
