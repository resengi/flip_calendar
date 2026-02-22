import 'package:flutter/foundation.dart';

/// Controller for managing calendar navigation state.
///
/// Manages the currently displayed month and provides methods for
/// programmatic navigation. Listeners are notified when the month
/// changes or when animation state changes.
///
/// ```dart
/// final controller = CalendarController(initialMonth: DateTime.now());
/// controller.addListener(() {
///   print('Month: ${controller.currentMonth}');
///   print('Animating: ${controller.isAnimating}');
/// });
///
/// controller.nextMonth();
/// controller.goToMonth(DateTime(2024, 12, 1));
/// ```
class CalendarController extends ChangeNotifier {
  CalendarController({DateTime? initialMonth})
      : _currentMonth = _normalizeMonth(initialMonth ?? DateTime.now());

  DateTime _currentMonth;
  bool _isAnimating = false;

  /// The currently displayed month (always the 1st at midnight).
  DateTime get currentMonth => _currentMonth;

  /// Whether a transition animation is in progress.
  ///
  /// Useful for disabling external UI (like header buttons) during animation.
  bool get isAnimating => _isAnimating;

  static DateTime _normalizeMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Updates animation state. Called internally by the calendar widget.
  @internal
  void setAnimating(bool animating) {
    if (_isAnimating != animating) {
      _isAnimating = animating;
      notifyListeners();
    }
  }

  /// Navigates to the specified month. No-op if already on that month.
  void goToMonth(DateTime month) {
    final normalized = _normalizeMonth(month);
    if (_currentMonth.year == normalized.year &&
        _currentMonth.month == normalized.month) {
      return;
    }
    _currentMonth = normalized;
    notifyListeners();
  }

  /// Navigates to the next month.
  void nextMonth() {
    goToMonth(DateTime(_currentMonth.year, _currentMonth.month + 1, 1));
  }

  /// Navigates to the previous month.
  void previousMonth() {
    goToMonth(DateTime(_currentMonth.year, _currentMonth.month - 1, 1));
  }

  /// Navigates to the current month (today's month).
  void goToToday() {
    goToMonth(DateTime.now());
  }

  /// Navigates to a specific year and month.
  void goToYearMonth(int year, int month) {
    goToMonth(DateTime(year, month, 1));
  }
}
