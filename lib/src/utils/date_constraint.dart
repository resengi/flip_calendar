/// A constraint that defines a date boundary for the calendar.
///
/// Supports both static dates and dynamic dates that recompute at runtime.
///
/// ```dart
/// // Fixed date
/// DateConstraint.fixed(DateTime(2020, 1, 1))
///
/// // Today (recomputed each build)
/// DateConstraint.today()
///
/// // Relative to today
/// DateConstraint.relative(years: -2, months: 3)
/// ```
class DateConstraint {
  /// Creates a constraint for a fixed/static date (normalized to midnight).
  factory DateConstraint.fixed(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return DateConstraint._(() => normalized);
  }

  /// Creates a constraint for today's date (recomputed on each [resolve]).
  factory DateConstraint.today() {
    return DateConstraint._(() {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    });
  }

  /// Creates a constraint relative to today (recomputed on each [resolve]).
  ///
  /// All parameters can be positive (future) or negative (past).
  factory DateConstraint.relative({
    int years = 0,
    int months = 0,
    int days = 0,
  }) {
    return DateConstraint._(() {
      final now = DateTime.now();
      return DateTime(now.year + years, now.month + months, now.day + days);
    });
  }

  const DateConstraint._(this._resolver);

  final DateTime Function() _resolver;

  /// Resolves this constraint to a concrete [DateTime].
  DateTime resolve() => _resolver();

  @override
  String toString() => 'DateConstraint(${resolve()})';
}
