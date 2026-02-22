/// How the calendar animates when navigating multiple months at once.
enum MultiMonthAnimationMode {
  /// Flip through each intermediate month sequentially.
  ///
  /// If the jump exceeds [FlipCalendar.maxAnimatedMonthJump],
  /// the transition is instant.
  sequential,

  /// Single flip directly from start to end month, regardless of distance.
  ///
  /// Ignores [FlipCalendar.maxAnimatedMonthJump].
  directJump,
}
