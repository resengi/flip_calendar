/// Pure date utility functions for the calendar.
///
/// All methods are static and have no side effects.
class CalendarDateUtils {
  CalendarDateUtils._();

  /// Normalizes a date to midnight (removes time component).
  static DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Checks if two dates are the same day.
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Checks if the given date is today.
  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  /// Checks if the given date is in the future (after today).
  static bool isFutureDate(DateTime date) {
    final normalizedDate = normalizeDate(date);
    final normalizedNow = normalizeDate(DateTime.now());
    return normalizedDate.isAfter(normalizedNow);
  }

  /// Checks if two dates are in the same month and year.
  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  /// Calculates the signed number of months between two dates.
  ///
  /// Returns positive if [dateB] is after [dateA], negative otherwise.
  static int monthsDelta(DateTime dateA, DateTime dateB) {
    return (dateB.year - dateA.year) * 12 + (dateB.month - dateA.month);
  }

  /// Checks if a date is selectable given optional min/max bounds (inclusive).
  static bool isDateSelectable(
    DateTime date, {
    DateTime? minDate,
    DateTime? maxDate,
  }) {
    final normalized = normalizeDate(date);

    if (minDate != null && normalized.isBefore(normalizeDate(minDate))) {
      return false;
    }
    if (maxDate != null && normalized.isAfter(normalizeDate(maxDate))) {
      return false;
    }
    return true;
  }

  /// Checks if a month contains at least one selectable date.
  static bool isMonthNavigable(
    DateTime month, {
    DateTime? minDate,
    DateTime? maxDate,
  }) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final lastOfMonth = DateTime(month.year, month.month + 1, 0);

    if (minDate != null && lastOfMonth.isBefore(normalizeDate(minDate))) {
      return false;
    }
    if (maxDate != null && firstOfMonth.isAfter(normalizeDate(maxDate))) {
      return false;
    }
    return true;
  }

  /// Clamps a month to be within the navigable range.
  static DateTime clampMonth(
    DateTime month, {
    DateTime? minDate,
    DateTime? maxDate,
  }) {
    var result = DateTime(month.year, month.month, 1);

    if (minDate != null) {
      final minMonth = DateTime(minDate.year, minDate.month, 1);
      if (result.isBefore(minMonth)) result = minMonth;
    }
    if (maxDate != null) {
      final maxMonth = DateTime(maxDate.year, maxDate.month, 1);
      if (result.isAfter(maxMonth)) result = maxMonth;
    }
    return result;
  }
}
