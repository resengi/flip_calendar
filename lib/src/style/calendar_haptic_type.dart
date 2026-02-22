/// Events that may trigger haptic feedback in the calendar.
///
/// The actual haptic implementation is the consumer's responsibility
/// via [FlipCalendar.onHapticFeedback].
enum CalendarHapticType {
  /// User attempted to navigate to a month outside the date bounds.
  navigationRestricted,
}
