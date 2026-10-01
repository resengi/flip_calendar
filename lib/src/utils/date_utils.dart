/// Date rules shared by the controller and the calendar.
///
/// None of these functions reads a clock: a rule that depends on today takes
/// it as an argument.
///
/// The dates they return are local dates built as
/// `DateTime(year, month, day)`: midnight, except on a day whose midnight a
/// daylight-saving change skips, where [DateTime] gives the first hour that
/// exists.
library;

/// [date]'s calendar day, as a local date.
///
/// Only the year, month and day are kept, so a UTC date gives the local date
/// with the same fields.
DateTime normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

/// The first day of [date]'s month, as a local date.
DateTime normalizeMonth(DateTime date) {
  return DateTime(date.year, date.month, 1);
}

/// The last day of [date]'s month, as a local date.
DateTime lastDayOfMonth(DateTime date) {
  return DateTime(date.year, date.month, daysInMonth(date.year, date.month));
}

/// Checks if two dates are the same day.
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Checks if [date] falls on a day after [today].
bool isFutureDate(DateTime date, DateTime today) {
  return normalizeDate(date).isAfter(normalizeDate(today));
}

/// Checks if two dates are in the same month and year.
bool isSameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

/// The number of calendar months from [dateA]'s month to [dateB]'s month:
/// positive when [dateB]'s month is later, negative when it is earlier, and 0
/// when both fall in the same month. Days are ignored.
int monthsDelta(DateTime dateA, DateTime dateB) {
  return (dateB.year - dateA.year) * 12 + (dateB.month - dateA.month);
}

/// Checks if a date is selectable given optional min/max bounds (inclusive).
///
/// Only calendar days are compared; a null bound leaves that side open.
bool isDateSelectable(DateTime date, {DateTime? minDate, DateTime? maxDate}) {
  final normalized = normalizeDate(date);

  if (minDate != null && normalized.isBefore(normalizeDate(minDate))) {
    return false;
  }
  if (maxDate != null && normalized.isAfter(normalizeDate(maxDate))) {
    return false;
  }
  return true;
}

/// The column (0–6) of [weekday] in a week that starts on [firstDayOfWeek].
///
/// Both use [DateTime]'s numbering, from [DateTime.monday] (1) to
/// [DateTime.sunday] (7). The package's callers pass only values in that
/// range: [DateTime.weekday], and a first day of the week that
/// `MonthGrid.forMonth` and `FlipCalendar` have checked.
int weekdayOffset(int weekday, int firstDayOfWeek) {
  return (weekday - firstDayOfWeek) % 7;
}

/// The index of the first complete month whose overflow cells are inside
/// DateTime's range, which starts on -271821-04-20.
const firstCalendarMonthIndex = -271821 * 12 + DateTime.may - 1;

/// The index of the last complete month whose overflow cells are inside
/// DateTime's range, which ends on 275760-09-13.
const lastCalendarMonthIndex = 275760 * 12 + DateTime.august - 1;

/// [date]'s month index. Days and times are ignored.
int calendarMonthIndex(DateTime date) => date.year * 12 + date.month - 1;

/// Whether [index] represents a complete month supported for every weekday
/// layout, including the days that fill its first and last weeks.
bool isSupportedCalendarMonthIndex(int index) {
  return index >= firstCalendarMonthIndex && index <= lastCalendarMonthIndex;
}

/// Normalizes [month] into 1 to 12, carrying whole years into [year].
({int year, int month}) normalizeYearMonth(int year, int month) {
  final index = month - 1;
  final monthIndex = index % 12;
  return (year: year + (index - monthIndex) ~/ 12, month: monthIndex + 1);
}

/// The first day of [index]'s month, as a local date.
DateTime calendarMonthFromIndex(int index) {
  final (:year, :month) = normalizeYearMonth(0, index + 1);
  return DateTime(year, month);
}

/// The Gregorian day count of [month], from 1 to 12, in [year].
int daysInMonth(int year, int month) {
  RangeError.checkValueInInterval(month, 1, 12, 'month');
  if (month == DateTime.february) {
    final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    return leap ? 29 : 28;
  }
  return switch (month) {
    DateTime.april ||
    DateTime.june ||
    DateTime.september ||
    DateTime.november => 30,
    _ => 31,
  };
}
