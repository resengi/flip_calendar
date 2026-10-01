import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../animation/multi_month_animation_mode.dart';
import '../utils/date_constraint.dart';
import '../utils/date_utils.dart';

/// Holds everything a calendar's navigation depends on: the month the
/// calendars are on, today, the allowed range, the animation settings and
/// whether a navigation is in progress.
///
/// Navigation never enters a month without an allowed day, and a request
/// made while a navigation is in progress is ignored. Listeners are notified
/// when [currentMonth], the bounds, the animation settings or [isNavigating]
/// change, and, with a clock, when the day of [today] changes. A change made
/// while Flutter builds, lays out or paints a frame is announced after that
/// frame. The app's first build runs before any frame, so a change made
/// during it is announced at once.
///
/// Calls that notify listeners need Flutter's binding, which an app has once
/// `runApp` (or `WidgetsFlutterBinding.ensureInitialized()`) has run; in a
/// plain `test()`, call `TestWidgetsFlutterBinding.ensureInitialized()`
/// first.
///
/// Any number of calendars can use one controller, and a calendar can switch
/// controllers.
///
/// ```dart
/// final controller = CalendarController();
/// controller.addListener(() {
///   debugPrint('${controller.currentMonth} ${controller.isNavigating}');
/// });
///
/// controller.nextMonth();
/// // While a calendar plays that navigation, another request is ignored, so
/// // wait for it to end first.
/// await controller.whenAtRest();
/// controller.goToMonth(DateTime(2024, 12, 1));
/// ```
class CalendarController extends ChangeNotifier {
  /// Creates a controller.
  ///
  /// [initialMonth] defaults to today's month.
  ///
  /// [clock] is the host's clock: [today] is the calendar day of its value,
  /// and listeners are notified when that day changes. The clock is fixed for
  /// the controller's life and must outlive it; to change what drives the
  /// calendar, change the clock's value rather than the clock. Without a
  /// clock, [today] is read from the device clock when needed, and a calendar
  /// shows a new day only when something rebuilds it.
  ///
  /// Throws an [ArgumentError] if [minDate] resolves after [maxDate] today, if
  /// a bound resolves outside the dates [DateTime] supports, or if the
  /// starting month has no allowed day, and a [RangeError] if
  /// [maxAnimatedMonthJump] is negative.
  CalendarController({
    DateTime? initialMonth,
    ValueListenable<DateTime>? clock,
    DateConstraint? minDate,
    DateConstraint? maxDate,
    bool animationsEnabled = true,
    int maxAnimatedMonthJump = 6,
    MultiMonthAnimationMode multiMonthAnimationMode =
        MultiMonthAnimationMode.sequential,
  }) : this._(
         initialMonth,
         clock,
         _todayFrom(clock),
         minDate,
         maxDate,
         animationsEnabled,
         maxAnimatedMonthJump,
         multiMonthAnimationMode,
       );

  /// The public constructor's work, with today read once, as [today].
  CalendarController._(
    DateTime? initialMonth,
    ValueListenable<DateTime>? clock,
    DateTime today,
    DateConstraint? minDate,
    DateConstraint? maxDate,
    bool animationsEnabled,
    int maxAnimatedMonthJump,
    MultiMonthAnimationMode multiMonthAnimationMode,
  ) : _clock = clock,
      _clockDay = clock == null ? null : today,
      _minDate = minDate,
      _maxDate = maxDate,
      _animationsEnabled = animationsEnabled,
      _maxAnimatedMonthJump = RangeError.checkNotNegative(
        maxAnimatedMonthJump,
        'maxAnimatedMonthJump',
      ),
      _multiMonthAnimationMode = multiMonthAnimationMode,
      _currentMonth = _startingMonth(initialMonth, today, minDate, maxDate) {
    clock?.addListener(_onClockTick);
  }

  final ValueListenable<DateTime>? _clock;
  DateTime? _clockDay;
  DateTime _currentMonth;
  DateConstraint? _minDate;
  DateConstraint? _maxDate;
  bool _animationsEnabled;
  int _maxAnimatedMonthJump;
  MultiMonthAnimationMode _multiMonthAnimationMode;
  final Set<ControlledCalendar> _calendars = {};
  final Set<ControlledCalendar> _owing = {};
  List<DateTime> _pages = const [];
  Completer<void>? _atRest;
  Completer<void>? _shown;
  bool _notificationScheduled = false;
  bool _disposed = false;

  /// The first day of the month the calendars rest on, as a local date.
  ///
  /// Set when a navigation is accepted, so it can be read right after the
  /// call: during a navigation it is already the month being turned to, while
  /// the calendars still show the months on the way.
  DateTime get currentMonth => _currentMonth;

  /// Today's date: the calendar day of the clock's value, or of the device
  /// clock when there is no clock, as a local `DateTime(year, month, day)`.
  DateTime get today => _todayFrom(_clock);

  /// The earliest allowed date, or null if there is no lower bound.
  ///
  /// Set with [setBounds].
  DateConstraint? get minDate => _minDate;

  /// The latest allowed date, or null if there is no upper bound.
  ///
  /// Set with [setBounds].
  DateConstraint? get maxDate => _maxDate;

  /// Replaces both bounds. A null bound leaves that side open.
  ///
  /// Throws an [ArgumentError] if [minDate] resolves after [maxDate] today,
  /// or if a bound resolves outside the dates [DateTime] supports. Notifies
  /// listeners only if a bound changed by value. The month on screen
  /// is not moved, even if it no longer has an allowed day.
  void setBounds(DateConstraint? minDate, DateConstraint? maxDate) {
    _resolveNotCrossed(minDate, maxDate, today);
    if (minDate == _minDate && maxDate == _maxDate) return;
    _minDate = minDate;
    _maxDate = maxDate;
    _notify();
  }

  /// Whether navigations animate.
  ///
  /// Notifies listeners when it changes. A change during a navigation applies
  /// from the next one.
  bool get animationsEnabled => _animationsEnabled;

  set animationsEnabled(bool value) {
    if (value == _animationsEnabled) return;
    _animationsEnabled = value;
    _notify();
  }

  /// The largest distance, in months, that
  /// [MultiMonthAnimationMode.sequential] animates; a longer navigation
  /// changes the month without animating.
  ///
  /// Throws a [RangeError] if set to a negative value. Notifies listeners when
  /// it changes. A change during a navigation applies from the next one.
  int get maxAnimatedMonthJump => _maxAnimatedMonthJump;

  set maxAnimatedMonthJump(int value) {
    RangeError.checkNotNegative(value, 'maxAnimatedMonthJump');
    if (value == _maxAnimatedMonthJump) return;
    _maxAnimatedMonthJump = value;
    _notify();
  }

  /// How a navigation across several months animates.
  ///
  /// Notifies listeners when it changes. A change during a navigation applies
  /// from the next one.
  MultiMonthAnimationMode get multiMonthAnimationMode =>
      _multiMonthAnimationMode;

  set multiMonthAnimationMode(MultiMonthAnimationMode value) {
    if (value == _multiMonthAnimationMode) return;
    _multiMonthAnimationMode = value;
    _notify();
  }

  /// Whether a navigation is in progress.
  ///
  /// Turns on when a navigation is accepted while a calendar uses this
  /// controller, and when a swipe begins. Turns off once every calendar that
  /// owes the navigation has shown the result or stopped using the
  /// controller: the calendars using the controller when it was accepted, or,
  /// for a swipe, the swiped calendar and, once the swipe lands, the others
  /// using the controller then. Requests made meanwhile are ignored.
  bool get isNavigating => _owing.isNotEmpty;

  /// Whether [date]'s day lies within the bounds, both ends included.
  bool isDateAllowed(DateTime date) {
    final (:min, :max) = _resolvedBounds(today);
    return isDateSelectable(date, minDate: min, maxDate: max);
  }

  /// Whether [month] has at least one allowed day.
  bool canGoTo(DateTime month) {
    final (:min, :max) = _resolvedBounds(today);
    return _hasAllowedDay(normalizeMonth(month), min, max);
  }

  /// The month of [minDate] today, or null if there is no lower bound.
  ///
  /// When the bounds have crossed (as today moved), no month is allowed,
  /// whatever this returns.
  DateTime? get firstAllowedMonth {
    final min = _minDate?.resolve(today);
    return min == null ? null : normalizeMonth(min);
  }

  /// The month of [maxDate] today, or null if there is no upper bound.
  ///
  /// When the bounds have crossed (as today moved), no month is allowed,
  /// whatever this returns.
  DateTime? get lastAllowedMonth {
    final max = _maxDate?.resolve(today);
    return max == null ? null : normalizeMonth(max);
  }

  /// The months a navigation to [month] would show, in order, ending with the
  /// month it would land on; empty if nothing would move, including while
  /// [isNavigating].
  ///
  /// The list starts with [currentMonth] when the navigation animates. It
  /// answers as if the calendar is on screen: a calendar that is not on screen
  /// when the request is made shows only the last month.
  ///
  /// The answer is exact for a request made before anything else changes. A
  /// setting, the bounds, today, or a swipe that starts or lands in between
  /// can change the pages the request shows, so a host that loads these
  /// months should request the month right after asking.
  List<DateTime> monthsOnWayTo(DateTime month) => _pagesTo(month, today);

  /// Completes when no navigation is in progress: at once if none is,
  /// otherwise when [isNavigating] turns off.
  ///
  /// Also completes when the controller is disposed, so code that resumes
  /// after it should check that its widget is still mounted before using the
  /// controller.
  Future<void> whenAtRest() {
    if (_disposed || !isNavigating) return Future<void>.value();
    return (_atRest ??= Completer<void>()).future;
  }

  /// Completes once a calendar using this controller is on screen: painted,
  /// with its animations running.
  ///
  /// Waits for a calendar to start using the controller if none does. Also
  /// completes when the controller is disposed, so code that resumes after it
  /// should check that its widget is still mounted before using the
  /// controller.
  ///
  /// To flip a calendar that may be hidden, wait for this before asking
  /// [monthsOnWayTo] and navigating:
  ///
  /// ```dart
  /// await controller.whenShown();
  /// final pages = controller.monthsOnWayTo(september);
  /// await loadMonths(pages);
  /// controller.goToMonth(september);
  /// await controller.whenAtRest();
  /// ```
  Future<void> whenShown() {
    if (_disposed) return Future<void>.value();
    final shown = _shown ??= Completer<void>();
    for (final calendar in _calendars) {
      calendar.checkOnScreen();
    }
    return shown.future;
  }

  /// Navigates to [month].
  ///
  /// Ignored while [isNavigating]. If [month] has no allowed day, lands on
  /// the allowed month nearest [month] among the allowed months in the
  /// direction of [month] from [currentMonth]; if there is none, or it lands
  /// on [currentMonth], nothing happens. An accepted navigation sets
  /// [currentMonth] at once and notifies listeners.
  void goToMonth(DateTime month) => _goTo(month, today);

  /// Navigates to the next month, as [goToMonth] does.
  void nextMonth() {
    goToMonth(DateTime(_currentMonth.year, _currentMonth.month + 1, 1));
  }

  /// Navigates to the previous month, as [goToMonth] does.
  void previousMonth() {
    goToMonth(DateTime(_currentMonth.year, _currentMonth.month - 1, 1));
  }

  /// Navigates to [today]'s month, as [goToMonth] does. Today is read once,
  /// for the target and the bounds alike.
  void goToToday() {
    final today = this.today;
    _goTo(today, today);
  }

  /// Navigates to [month], from 1 to 12, of [year], as [goToMonth] does.
  ///
  /// Throws a [RangeError] if [month] is outside 1 to 12, or if that month is
  /// outside the dates [DateTime] supports.
  void goToYearMonth(int year, int month) {
    RangeError.checkValueInInterval(month, 1, 12, 'month');
    final DateTime target;
    try {
      target = DateTime(year, month);
    } on ArgumentError {
      // DateTime's constructor throws this, and only this, for a date
      // outside its range.
      throw RangeError.value(
        year,
        'year',
        'Outside the dates DateTime supports',
      );
    }
    goToMonth(target);
  }

  /// Adds [calendar], which is not joined, to the calendars using this
  /// controller. While a [whenShown] caller waits, the calendar is asked to
  /// check whether it is on screen.
  @internal
  void calendarJoined(ControlledCalendar calendar) {
    _calendars.add(calendar);
    if (_shown != null) calendar.checkOnScreen();
  }

  /// Removes [calendar], a joined calendar, from the calendars using this
  /// controller. It no longer owes any navigation; if it was the last
  /// calendar the navigation waited for, the navigation ends.
  @internal
  void calendarLeft(ControlledCalendar calendar) {
    _calendars.remove(calendar);
    if (_owing.remove(calendar) && _owing.isEmpty) {
      _settle();
      _notify();
    }
  }

  /// A swipe toward [month], the month next to [currentMonth] in the swipe's
  /// direction, began on [calendar]. Called only while not [isNavigating].
  ///
  /// Records as [calendarPages] the pages a request for [month] would show
  /// now, by the rule of [monthsOnWayTo]: empty if nothing would move,
  /// otherwise ending with the month the swipe lands on. Settings changed
  /// during the swipe don't change them. Then [calendar] owes the swipe, and
  /// listeners are notified.
  @internal
  void calendarSwipeStarted(ControlledCalendar calendar, DateTime month) {
    _pages = _pagesTo(month, today);
    _owing.add(calendar);
    _notify();
  }

  /// [calendar], which owes the navigation in progress, has shown its result.
  ///
  /// [landed] is true for a swipe that reached its month: [currentMonth]
  /// becomes the last recorded page, and the other joined calendars owe the
  /// navigation and show the recorded pages.
  @internal
  void calendarDone(ControlledCalendar calendar, {bool landed = false}) {
    _owing.remove(calendar);
    if (landed) {
      _owing.addAll(_calendars.where((joined) => joined != calendar));
      _currentMonth = _pages.last;
    }
    final settled = _owing.isEmpty;
    if (settled) _settle();
    if (settled || landed) _notify();
  }

  /// A joined calendar asked by [ControlledCalendar.checkOnScreen] is on
  /// screen. Completes every [whenShown] caller; ignored when nobody is
  /// waiting.
  @internal
  void calendarOnScreen() {
    final shown = _shown;
    if (shown == null) return;
    _shown = null;
    shown.complete();
  }

  /// The pages of the navigation in progress, by the rule of
  /// [monthsOnWayTo], recorded when a navigation is accepted or a swipe
  /// starts; empty at rest.
  @internal
  List<DateTime> get calendarPages => _pages;

  @override
  void dispose() {
    _disposed = true;
    _clock?.removeListener(_onClockTick);
    _atRest?.complete();
    _atRest = null;
    _shown?.complete();
    _shown = null;
    super.dispose();
  }

  void _settle() {
    _pages = const [];
    _atRest?.complete();
    _atRest = null;
  }

  void _onClockTick() {
    final day = _todayFrom(_clock);
    if (day == _clockDay) return;
    _clockDay = day;
    _notify();
  }

  /// Notifies listeners, or, during Flutter's build, layout and paint step,
  /// once after the frame for every change made in it.
  void _notify() {
    assert(ChangeNotifier.debugAssertNotDisposed(this));
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase != SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    scheduler.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (!_disposed) notifyListeners();
    }, debugLabel: 'CalendarController.notify');
  }

  /// The navigation of [goToMonth], with the bounds resolved against [today].
  void _goTo(DateTime month, DateTime today) {
    final pages = _pagesTo(month, today);
    if (pages.isEmpty) return;
    _currentMonth = pages.last;
    if (_calendars.isNotEmpty) {
      _owing.addAll(_calendars);
      _pages = pages;
    }
    _notify();
  }

  /// The answer of [monthsOnWayTo], with the bounds resolved against [today].
  List<DateTime> _pagesTo(DateTime month, DateTime today) {
    if (isNavigating) return [];
    final (:min, :max) = _resolvedBounds(today);
    final landing = _landingMonth(normalizeMonth(month), min, max);
    return landing == null ? [] : _pagesBetween(_currentMonth, landing);
  }

  ({DateTime? min, DateTime? max}) _resolvedBounds(DateTime today) {
    return (min: _minDate?.resolve(today), max: _maxDate?.resolve(today));
  }

  /// The month a request for [target] (a first of the month) lands on, or
  /// null if nothing would move.
  DateTime? _landingMonth(DateTime target, DateTime? min, DateTime? max) {
    if (_hasAllowedDay(target, min, max)) {
      return isSameMonth(target, _currentMonth) ? null : target;
    }
    if (_isCrossed(min, max)) return null;
    // The target lies outside the allowed months. Without an upper bound, a
    // target not before the lower bound's month would have an allowed day.
    final first = min == null ? null : normalizeMonth(min);
    final nearest = first != null && target.isBefore(first)
        ? first
        : normalizeMonth(max!);
    // A target in the current month has direction 0; the nearest month has
    // an allowed day, so it is another month, and the result is null.
    final direction = monthsDelta(_currentMonth, target).sign;
    return monthsDelta(_currentMonth, nearest).sign == direction
        ? nearest
        : null;
  }

  /// The pages shown on the way from [from] to [to], two different months.
  List<DateTime> _pagesBetween(DateTime from, DateTime to) {
    if (!_animationsEnabled) return [to];
    switch (_multiMonthAnimationMode) {
      case MultiMonthAnimationMode.directJump:
        return [from, to];
      case MultiMonthAnimationMode.sequential:
        final distance = monthsDelta(from, to);
        if (distance.abs() > _maxAnimatedMonthJump) return [to];
        return [
          for (var step = 0; step <= distance.abs(); step++)
            DateTime(from.year, from.month + step * distance.sign, 1),
        ];
    }
  }

  static DateTime _todayFrom(ValueListenable<DateTime>? clock) {
    return normalizeDate(clock?.value ?? DateTime.now());
  }

  static DateTime _startingMonth(
    DateTime? initialMonth,
    DateTime today,
    DateConstraint? minDate,
    DateConstraint? maxDate,
  ) {
    final (:min, :max) = _resolveNotCrossed(minDate, maxDate, today);
    final month = normalizeMonth(initialMonth ?? today);
    if (!_hasAllowedDay(month, min, max)) {
      throw ArgumentError.value(month, 'initialMonth', 'Has no allowed day');
    }
    return month;
  }

  /// [minDate] and [maxDate] resolved against [today]. Throws an
  /// [ArgumentError] if they are crossed.
  static ({DateTime? min, DateTime? max}) _resolveNotCrossed(
    DateConstraint? minDate,
    DateConstraint? maxDate,
    DateTime today,
  ) {
    final min = minDate?.resolve(today);
    final max = maxDate?.resolve(today);
    if (_isCrossed(min, max)) {
      throw ArgumentError.value(minDate, 'minDate', 'Is after maxDate');
    }
    return (min: min, max: max);
  }

  static bool _isCrossed(DateTime? min, DateTime? max) {
    return min != null && max != null && min.isAfter(max);
  }

  static bool _hasAllowedDay(DateTime month, DateTime? min, DateTime? max) {
    if (_isCrossed(min, max)) return false;
    return (min == null || !lastDayOfMonth(month).isBefore(min)) &&
        (max == null || !month.isAfter(max));
  }
}

/// A calendar driven by a [CalendarController], as the controller sees it.
@internal
abstract interface class ControlledCalendar {
  /// Reports [CalendarController.calendarOnScreen] after the first frame in
  /// which this calendar is on screen.
  void checkOnScreen();
}
