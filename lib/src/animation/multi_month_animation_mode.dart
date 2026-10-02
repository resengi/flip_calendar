/// @docImport '../calendar/calendar_controller.dart';
library;

/// How a navigation request turns the calendar's pages when animations are
/// enabled.
///
/// The mode applies to every request, including one to the next or previous
/// month.
enum MultiMonthAnimationMode {
  /// One page turn per month moved, if the request moves at most
  /// [CalendarController.maxAnimatedMonthJump] months; otherwise the month
  /// changes without a page turn.
  ///
  /// With a [CalendarController.maxAnimatedMonthJump] of 0, even a move to
  /// the next or previous month changes without a page turn.
  sequential,

  /// One page turn from the current month to the target, whatever the
  /// distance.
  ///
  /// Ignores [CalendarController.maxAnimatedMonthJump].
  directJump,
}
