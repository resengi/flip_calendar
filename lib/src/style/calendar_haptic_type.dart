/// @docImport '../calendar/flip_calendar.dart';
library;

/// Events that may trigger haptic feedback in the calendar.
///
/// The actual haptic implementation is the consumer's responsibility
/// via [FlipCalendar.onHapticFeedback].
enum CalendarHapticType {
  /// A swipe started toward a month outside the date bounds, with no allowed
  /// month beyond it in that direction, so it cannot land.
  ///
  /// Sent once, when the swipe starts. A swipe with an allowed month in its
  /// direction sends nothing, and neither does a navigation request.
  navigationRestricted,
}
