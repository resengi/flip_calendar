/// Date rules shared by the controller and the calendar.
///
/// None of these functions reads a clock: a rule that depends on today takes
/// it as an argument.
///
/// Dates returned by these utilities are local dates constructed from
/// Gregorian year, month and day fields. Local timezone normalization
/// follows DateTime, including skipped local dates and times.
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
  return calendarMonthIndex(dateB) - calendarMonthIndex(dateA);
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
({BigInt year, int month}) normalizeYearMonth(
  BigInt year,
  BigInt month,
) {
  final index = month - BigInt.one;
  final monthIndex = index % BigInt.from(12);
  return (
    year: year + (index - monthIndex) ~/ BigInt.from(12),
    month: monthIndex.toInt() + 1,
  );
}

/// Constructs a local date from Gregorian fields.
///
/// [month] must be in 1 to 12. [day] may overflow its month.
/// Throws an [ArgumentError] when the resulting date is outside
/// DateTime's range. Local timezone normalization follows DateTime.
DateTime localDateFromCivilFields({
  required BigInt year,
  required int month,
  required BigInt day,
}) {
  RangeError.checkValueInInterval(month, 1, 12, 'month');

  final cycleLength = BigInt.from(400);
  final cycleYear = year % cycleLength;
  final cycles = (year - cycleYear) ~/ cycleLength;
  final cycleStart = DateTime.utc(cycleYear.toInt(), month);
  final dayIndex =
      BigInt.from(
        cycleStart.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay,
      ) +
      cycles * BigInt.from(146097) +
      day -
      BigInt.one;

  final limit = BigInt.from(100000000);
  if (dayIndex < -limit || dayIndex > limit) {
    throw ArgumentError('Outside the dates DateTime supports');
  }

  // UTC decodes Gregorian fields; the returned date is constructed locally.
  final civilDate = DateTime.fromMillisecondsSinceEpoch(
    dayIndex.toInt() * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return DateTime(civilDate.year, civilDate.month, civilDate.day);
}

/// The first day of [index]'s month, as a local date.
DateTime calendarMonthFromIndex(int index) {
  final (:year, :month) = normalizeYearMonth(
    BigInt.zero,
    BigInt.from(index) + BigInt.one,
  );
  return localDateFromCivilFields(
    year: year,
    month: month,
    day: BigInt.one,
  );
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
