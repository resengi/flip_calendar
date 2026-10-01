import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

import '../animation/calendar_gesture_handler.dart';
import '../style/calendar_haptic_type.dart';
import '../style/calendar_style.dart';
import '../utils/date_utils.dart';
import 'calendar_controller.dart';
import 'calendar_day_data.dart';
import 'calendar_grid.dart';

/// A month calendar that turns its pages like a wall calendar.
///
/// The [controller] holds the month shown, the allowed range, today and the
/// animation settings. The calendar draws what the controller holds, plays
/// its navigations, and reports swipes to it. Day cells are built by
/// [dayBuilder].
///
/// The calendar fills the space it is given, which must be bounded in both
/// directions: inside a scrollable, give it a size along the scroll axis.
///
/// ```dart
/// final controller = CalendarController();
///
/// FlipCalendar(
///   controller: controller,
///   selectedDate: _selectedDate,
///   onDayTap: (date) => setState(() => _selectedDate = date),
///   dayBuilder: (context, data) {
///     return Center(
///       child: Text(
///         data.date.day.toString(),
///         style: TextStyle(
///           color: data.isEnabled ? Colors.black : Colors.grey,
///         ),
///       ),
///     );
///   },
/// )
/// ```
class FlipCalendar extends StatefulWidget {
  const FlipCalendar({
    required this.controller,
    required this.dayBuilder,
    this.selectedDate,
    this.onDayTap,
    this.onHapticFeedback,
    this.style = const CalendarStyle(),
    this.firstDayOfWeek = DateTime.sunday,
    this.boundEdge = PageTurnEdge.top,
    this.gesturesEnabled = true,
    super.key,
  });

  /// Controller for managing the displayed month.
  ///
  /// Several calendars can share one controller. Replacing it moves the
  /// calendar to the new controller's month at once, and any navigation it
  /// was playing for the old controller ends.
  final CalendarController controller;

  /// Builder for each day cell. Receives [CalendarDayData] with all
  /// information needed to render the cell.
  final Widget Function(BuildContext context, CalendarDayData data) dayBuilder;

  /// The currently selected date (matching cell gets `isSelected: true`).
  final DateTime? selectedDate;

  /// Called when an enabled day cell is tapped.
  final void Function(DateTime date)? onDayTap;

  /// Called for haptic feedback events (consumer implements actual haptics).
  final void Function(CalendarHapticType type)? onHapticFeedback;

  /// Style configuration for the calendar.
  final CalendarStyle style;

  /// First day of the week: [DateTime.monday] (1) through [DateTime.sunday]
  /// (7). Checked at build; any other value throws a [RangeError].
  final int firstDayOfWeek;

  /// Edge where calendar pages are bound (determines gesture direction).
  final PageTurnEdge boundEdge;

  /// Whether swipe gestures are enabled for navigation.
  ///
  /// Swipes navigate whether or not the controller's animations are enabled:
  /// with animations off, a completed swipe changes the month without a page
  /// turn. To have no swipes when animations are off, set this from the same
  /// setting.
  final bool gesturesEnabled;

  @override
  State<FlipCalendar> createState() => _FlipCalendarState();
}

/// What the calendar shows: [idle], its page; [capturing], its page and the
/// page that turns, for capture; [animating], a page turn.
enum _Phase { idle, capturing, animating }

class _FlipCalendarState extends State<FlipCalendar>
    with SingleTickerProviderStateMixin
    implements ControlledCalendar {
  /// Drives page turns: 0 shows the page turned from, 1 the page turned to.
  /// A drag sets it to the drag's progress; a turn that runs by itself
  /// follows the style's curve from wherever the page is.
  late final AnimationController _flipController;

  /// The key of the page captured for the turn: the page turned from for a
  /// forward turn, the page turned to for a backward one.
  final GlobalKey _captureKey = GlobalKey();

  /// The captured page; set exactly while animating.
  ui.Image? _image;

  /// What the calendar shows now.
  _Phase _phase = _Phase.idle;

  /// Whether the page turn in progress, or the swipe, goes to a later month.
  bool _isForward = true;

  /// True from a swipe's start until the swipe ends.
  bool _isGestureControlled = false;

  /// True from a swipe's start until release, cancellation or failure.
  bool _dragActive = false;

  /// The release decision: null until release; true lands, false snaps back.
  bool? _pendingGestureResult;

  /// The swipe has nowhere to land.
  bool _isRestricted = false;

  /// How far a restricted swipe lifts the page.
  static const double _restrictedMaxProgress = 0.02;

  /// The page shown at rest, and the page turned from during a flip.
  late DateTime _shownMonth;

  /// The controller's month at its last notification.
  late DateTime _controllerMonth;

  /// The month the page turn in progress, or the swipe, turns to: for a
  /// swipe, the landing month, or the adjacent month when the swipe is
  /// restricted. An unsupported adjacent grid uses the shown month instead.
  /// Set until the calendar goes idle, also during a swipe with
  /// animations off, when the phase stays idle.
  DateTime? _targetMonth;

  /// The pages of a sequential navigation still to turn to after
  /// [_targetMonth].
  List<DateTime> _remainingPages = const [];

  /// The status that ends the running flip; null when no flip runs.
  AnimationStatus? _flipEndStatus;

  /// Incremented whenever the calendar goes idle. A post-frame callback for a
  /// capture or a report acts only if it is unchanged.
  int _flipGeneration = 0;

  /// Incremented by the probe on every paint made while the calendar's
  /// animations run.
  int _paintCount = 0;

  /// [_paintCount] when the current capture pages were set up.
  int _paintsBeforeCapture = 0;

  /// A [checkOnScreen] request not yet answered.
  bool _onScreenCheckPending = false;

  ValueListenable<TickerModeData>? _tickerMode;

  @override
  void initState() {
    super.initState();
    // Each page turn sets its duration when it is prepared.
    _flipController = AnimationController(vsync: this)
      ..addStatusListener(_onFlipStatus);
    _shownMonth = widget.controller.currentMonth;
    _updateTickerModeNotifier();
    _join();
  }

  @override
  void activate() {
    super.activate();
    _updateTickerModeNotifier();
    _shownMonth = widget.controller.currentMonth;
    _join();
  }

  @override
  void deactivate() {
    _leave(widget.controller);
    super.deactivate();
  }

  @override
  void didUpdateWidget(FlipCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _leave(oldWidget.controller);
      _shownMonth = widget.controller.currentMonth;
      _join();
    } else if (!widget.gesturesEnabled ||
        widget.boundEdge != oldWidget.boundEdge ||
        _inputError() != null) {
      // The drag's gesture handler goes away, or reads its drags another
      // way: an active swipe ends without moving.
      _onDragComplete(false);
    }
  }

  @override
  void dispose() {
    _tickerMode?.removeListener(_onTickerModeChanged);
    _flipController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Joining, leaving and the controller listener
  // ---------------------------------------------------------------------------

  void _join() {
    _controllerMonth = widget.controller.currentMonth;
    widget.controller.addListener(_onControllerChanged);
    widget.controller.calendarJoined(this);
  }

  /// Leaves [controller]. The shown month is set again before the calendar
  /// next joins a controller.
  void _leave(CalendarController controller) {
    controller.removeListener(_onControllerChanged);
    controller.calendarLeft(this);
    _onScreenCheckPending = false;
    _goIdle();
  }

  /// Starts playing a navigation when the controller's month has changed and
  /// is not the month shown; every notification redraws.
  void _onControllerChanged() {
    final month = widget.controller.currentMonth;
    final monthChanged = !isSameMonth(month, _controllerMonth);
    _controllerMonth = month;
    if (monthChanged && !isSameMonth(month, _shownMonth)) _startNavigation();
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Playing a navigation
  // ---------------------------------------------------------------------------

  void _startNavigation() {
    final pages = widget.controller.calendarPages;
    if (pages.length < 2) {
      _endAndReport(reportNow: false);
      return;
    }
    _isForward = monthsDelta(pages.first, pages.last) > 0;
    _flipController.duration =
        widget.style.animationDuration ~/ (pages.length - 1);
    _remainingPages = pages.sublist(2);
    _prepareFlip(pages[1]);
  }

  /// Sets up the capture for a page turn to [target]. The calendar redraws
  /// afterwards: the callers call `setState`, except [_startNavigation],
  /// whose caller, the controller listener, does.
  void _prepareFlip(DateTime target) {
    _flipController.value = 0;
    _targetMonth = target;
    _phase = _Phase.capturing;
    _paintsBeforeCapture = _paintCount;
    _requestProbePaint();
    final generation = _flipGeneration;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_flipGeneration == generation) _onCaptureFrameDrawn();
    });
  }

  void _onCaptureFrameDrawn() {
    final onScreen = _isOnScreenSince(_paintsBeforeCapture);
    if (!onScreen || !_captureImage()) {
      // A swipe ends where it started, with nothing new to draw; a
      // navigation on screen draws its month before it reports.
      _endAndReport(reportNow: _isGestureControlled || !onScreen);
      return;
    }
    setState(() => _phase = _Phase.animating);
    final gestureResult = _pendingGestureResult;
    if (!_isGestureControlled) {
      _runFlip(forward: true);
    } else if (gestureResult != null) {
      _runFlip(forward: gestureResult);
    }
  }

  /// Captures the page that turns; false if it was not built in the capture
  /// frame (its redraw failed), has no size, or the capture throws. A capture
  /// that throws is reported.
  bool _captureImage() {
    final captureContext = _captureKey.currentContext;
    if (captureContext == null) return false;
    final page = captureContext.findRenderObject()! as RenderRepaintBoundary;
    if (page.size.isEmpty) return false;
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    try {
      _image = page.toImageSync(pixelRatio: pixelRatio);
    } catch (error, stack) {
      // Any error: a rasterization failure, a pixel ratio of 0, or, in debug
      // builds, a page marked for painting after the capture frame's paint.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'flip_calendar',
          context: ErrorDescription(
            'while capturing a calendar page for a page turn',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  void _disposeImage() {
    _image?.dispose();
    _image = null;
  }

  /// Runs the flip to 1 if [forward], otherwise to 0, along the style's curve
  /// from the page's current value.
  void _runFlip({required bool forward}) {
    // At the end already, animateTo and animateBack report no status change.
    if (_flipController.value == (forward ? 1.0 : 0.0)) {
      _onFlipEnded();
      return;
    }
    _flipEndStatus = forward
        ? AnimationStatus.completed
        : AnimationStatus.dismissed;
    final curve = widget.style.animationCurve;
    // Last: with a zero duration the status changes inside this call.
    if (forward) {
      _flipController.animateTo(1, curve: curve);
    } else {
      _flipController.animateBack(0, curve: curve);
    }
  }

  void _onFlipStatus(AnimationStatus status) {
    if (status != _flipEndStatus) return;
    _flipEndStatus = null;
    _onFlipEnded();
  }

  void _onFlipEnded() {
    if (_isGestureControlled) {
      _endAndReport(landed: _pendingGestureResult!, reportNow: false);
      return;
    }
    _shownMonth = _targetMonth!;
    _disposeImage();
    if (_remainingPages.isNotEmpty) {
      _prepareFlip(_remainingPages.removeAt(0));
      setState(() {});
      return;
    }
    _endAndReport(reportNow: false);
  }

  /// Ends the navigation or swipe: goes idle on the month it rests on and
  /// reports, now if [reportNow], otherwise after the next frame. [landed] is
  /// true only for a swipe that reached its month, which it then rests on;
  /// every other ending rests on the controller's month.
  ///
  /// It reports, or schedules its report, before it redraws: a redraw that
  /// throws must not keep the controller busy.
  void _endAndReport({required bool reportNow, bool landed = false}) {
    final month = landed ? _targetMonth! : widget.controller.currentMonth;
    _goIdle();
    _shownMonth = month;
    if (reportNow) {
      _report(landed: landed);
    } else {
      _reportAfterFrame(landed: landed);
    }
    setState(() {});
  }

  /// Stops any flip and swipe and drops their state. Leaves the shown month
  /// and the pending on-screen check as they are.
  void _goIdle() {
    _flipGeneration++;
    _flipEndStatus = null;
    // Stopping notifies no listener, so this is safe inside a build.
    _flipController.stop();
    _disposeImage();
    _phase = _Phase.idle;
    _targetMonth = null;
    _remainingPages = const [];
    _isGestureControlled = false;
    _dragActive = false;
    _pendingGestureResult = null;
    _isRestricted = false;
  }

  // ---------------------------------------------------------------------------
  // Swipes
  // ---------------------------------------------------------------------------

  void _onDragBegin(DragDirection direction) {
    final controller = widget.controller;
    if (controller.isNavigating) return;
    final forward = direction == DragDirection.next;
    final month = controller.currentMonth;
    final adjacentIndex = calendarMonthIndex(month) + (forward ? 1 : -1);
    final adjacent = isSupportedCalendarMonthIndex(adjacentIndex)
        ? calendarMonthFromIndex(adjacentIndex)
        : month;
    // Read before the swipe is registered: listeners of that notification may
    // change it, and the swipe keeps the setting it started with. A calendar
    // whose animations are paused swipes as with animations off.
    final animated = controller.animationsEnabled && _tickerMode!.value.enabled;
    controller.calendarSwipeStarted(this, adjacent);
    final pages = controller.calendarPages;
    final restricted = pages.isEmpty;
    final target = restricted ? adjacent : pages.last;
    _isGestureControlled = true;
    _dragActive = true;
    _isForward = forward;
    _isRestricted = restricted;
    _targetMonth = target;
    if (animated) {
      _flipController.duration = widget.style.animationDuration;
      _prepareFlip(target);
    }
    setState(() {});
    // Last, once the swipe is registered: a request the host makes from this
    // callback is ignored, as every request is while a swipe is in progress.
    if (restricted) {
      widget.onHapticFeedback?.call(CalendarHapticType.navigationRestricted);
    }
  }

  void _onDragProgress(double progress) {
    if (!_dragActive) return;
    _flipController.value = _isRestricted
        ? math.min(progress, _restrictedMaxProgress)
        : progress;
  }

  void _onDragComplete(bool shouldComplete) {
    if (!_dragActive) return;
    _dragActive = false;
    final lands =
        shouldComplete &&
        !_isRestricted &&
        widget.controller.canGoTo(_targetMonth!);
    _pendingGestureResult = lands;
    setState(() {});
    switch (_phase) {
      case _Phase.animating:
        _runFlip(forward: lands);
      case _Phase.idle:
        _endAndReport(landed: lands, reportNow: false);
      case _Phase.capturing:
      // The capture frame applies the decision.
    }
  }

  // ---------------------------------------------------------------------------
  // Reporting
  // ---------------------------------------------------------------------------

  void _report({bool landed = false}) {
    widget.controller.calendarDone(this, landed: landed);
  }

  /// Reports after the next frame, unless the calendar leaves its controller
  /// first.
  ///
  /// A swipe that [landed] on a month that is no longer allowed by then shows
  /// the controller's month again and reports that it did not move.
  void _reportAfterFrame({bool landed = false}) {
    final generation = _flipGeneration;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_flipGeneration != generation) return;
      if (landed && !widget.controller.canGoTo(_shownMonth)) {
        _shownMonth = widget.controller.currentMonth;
        _report();
        setState(() {});
        return;
      }
      _report(landed: landed);
    });
  }

  // ---------------------------------------------------------------------------
  // On screen
  // ---------------------------------------------------------------------------

  @override
  void checkOnScreen() {
    _onScreenCheckPending = true;
    _requestProbePaint();
  }

  /// Counts a paint made while the calendar's animations run: such a paint is
  /// on screen. A paint made while they are paused counts for nothing, now or
  /// after they resume. A counted paint answers a pending on-screen check
  /// after the frame.
  void _onProbePaint() {
    if (!_tickerMode!.value.enabled) return;
    _paintCount++;
    if (!_onScreenCheckPending) return;
    _onScreenCheckPending = false;
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => widget.controller.calendarOnScreen(),
    );
  }

  /// Asks the probe to paint. Nothing is asked when the build has no probe
  /// (a first build, or a failed one); such a calendar is not on screen.
  void _requestProbePaint() {
    final renderObject = context.findRenderObject();
    if (renderObject is _RenderOnScreenProbe) renderObject.markNeedsPaint();
  }

  /// Whether the probe made a counted paint after [paintCount] was recorded.
  bool _isOnScreenSince(int paintCount) => _paintCount > paintCount;

  void _updateTickerModeNotifier() {
    final notifier = TickerMode.getValuesNotifier(context);
    if (notifier == _tickerMode) return;
    _tickerMode?.removeListener(_onTickerModeChanged);
    notifier.addListener(_onTickerModeChanged);
    _tickerMode = notifier;
  }

  /// Once animations resume, a pending on-screen check needs a paint that
  /// counts.
  void _onTickerModeChanged() {
    if (_onScreenCheckPending && _tickerMode!.value.enabled) {
      _requestProbePaint();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final inputError = _inputError();
    if (inputError != null) throw inputError;
    final controller = widget.controller;
    final today = controller.today;
    final resolvedMinDate = controller.minDate?.resolve(today);
    final resolvedMaxDate = controller.maxDate?.resolve(today);

    Widget buildPage(DateTime month) {
      return CalendarGrid(
        month: month,
        today: today,
        selectedDate: widget.selectedDate,
        resolvedMinDate: resolvedMinDate,
        resolvedMaxDate: resolvedMaxDate,
        firstDayOfWeek: widget.firstDayOfWeek,
        style: widget.style,
        dayBuilder: widget.dayBuilder,
        onDayTap: widget.onDayTap,
      );
    }

    var content = _buildForPhase(buildPage);
    if (widget.gesturesEnabled) {
      content = CalendarGestureHandler(
        boundEdge: widget.boundEdge,
        style: widget.style,
        onDragBegin: _onDragBegin,
        onDragProgress: _onDragProgress,
        onDragComplete: _onDragComplete,
        child: content,
      );
    }
    return _OnScreenProbe(onPaint: _onProbePaint, child: content);
  }

  /// The error for the first input that is out of range,
  /// [FlipCalendar.firstDayOfWeek] or a checked style value, or null.
  ArgumentError? _inputError() {
    final firstDayOfWeek = widget.firstDayOfWeek;
    if (!(firstDayOfWeek >= DateTime.monday &&
        firstDayOfWeek <= DateTime.sunday)) {
      return RangeError.range(
        firstDayOfWeek,
        DateTime.monday,
        DateTime.sunday,
        'firstDayOfWeek',
      );
    }
    final style = widget.style;
    if (style.weekdayNames.length != 7) {
      return ArgumentError.value(
        style.weekdayNames,
        'style.weekdayNames',
        'Must contain exactly 7 names',
      );
    }
    final positiveError =
        _positiveFiniteError(
          style.flickDistanceThreshold,
          'style.flickDistanceThreshold',
        ) ??
        _positiveFiniteError(
          style.dragBoxSizePercentage,
          'style.dragBoxSizePercentage',
        );
    if (positiveError != null) return positiveError;
    final dragProgressThreshold = style.dragProgressThreshold;
    if (!(dragProgressThreshold > 0 && dragProgressThreshold <= 1)) {
      return RangeError.value(
        dragProgressThreshold,
        'style.dragProgressThreshold',
        'Must be greater than 0 and at most 1',
      );
    }
    if (!(style.flickMaxDuration > Duration.zero)) {
      return ArgumentError.value(
        style.flickMaxDuration,
        'style.flickMaxDuration',
        'Must be greater than zero',
      );
    }
    if (!(style.animationDuration >= Duration.zero)) {
      return ArgumentError.value(
        style.animationDuration,
        'style.animationDuration',
        'Must not be negative',
      );
    }
    return _notNegativeFiniteError(
          style.gridLineWidth,
          'style.gridLineWidth',
        ) ??
        _notNegativeFiniteError(
          style.weekdayHeaderHeight,
          'style.weekdayHeaderHeight',
        ) ??
        _notNegativeFiniteError(
          style.todayBorderWidth,
          'style.todayBorderWidth',
        ) ??
        _notNegativeFiniteError(style.dayTextSize, 'style.dayTextSize') ??
        _insetsError(style.padding, 'style.padding') ??
        _insetsError(style.todayMargin, 'style.todayMargin') ??
        _radiusError(style.borderRadius, 'style.borderRadius') ??
        _radiusError(style.todayBorderRadius, 'style.todayBorderRadius');
  }

  Widget _buildForPhase(Widget Function(DateTime month) buildPage) {
    switch (_phase) {
      case _Phase.capturing:
        final captured = RepaintBoundary(
          key: _captureKey,
          child: buildPage(_isForward ? _shownMonth : _targetMonth!),
        );
        if (_isForward) return captured;
        // The page turned to is captured under the page shown.
        return Stack(
          children: [
            Positioned.fill(child: captured),
            Positioned.fill(child: buildPage(_shownMonth)),
          ],
        );

      case _Phase.animating:
        return _buildPageFlip(
          underneath: buildPage(_isForward ? _targetMonth! : _shownMonth),
          image: _image!,
          animation: _flipController,
          isForward: _isForward,
          boundEdge: widget.boundEdge,
          pageTurnStyle: widget.style.pageTurnStyle,
        );

      case _Phase.idle:
        return buildPage(_shownMonth);
    }
  }
}

/// Builds a page turn: [image], the captured page that turns, over the live
/// [underneath] page. Forward, [image] is the page turned from and curls
/// away from the page turned to; backward, it is the page turned to and
/// curls in over the page turned from.
///
/// [animation] drives the turn from [boundEdge], and [pageTurnStyle] styles
/// the curl.
Widget _buildPageFlip({
  required Widget underneath,
  required ui.Image image,
  required Animation<double> animation,
  required bool isForward,
  required PageTurnEdge boundEdge,
  required PageTurnStyle pageTurnStyle,
}) {
  return Stack(
    children: [
      Positioned.fill(child: underneath),
      PageTurnAnimation(
        image: image,
        animation: animation,
        direction: isForward
            ? PageTurnDirection.forward
            : PageTurnDirection.backward,
        edge: boundEdge,
        style: pageTurnStyle,
      ),
    ],
  );
}

/// A [RangeError] naming [name] unless [value] is greater than 0 and finite;
/// otherwise null.
RangeError? _positiveFiniteError(double value, String name) {
  if (!(value > 0)) {
    return RangeError.value(value, name, 'Must be greater than 0');
  }
  return _finiteError(value, name);
}

/// A [RangeError] naming [name] unless [value] is at least 0 and finite;
/// otherwise null.
RangeError? _notNegativeFiniteError(double value, String name) {
  if (!(value >= 0)) return RangeError.range(value, 0, null, name);
  return _finiteError(value, name);
}

/// A [RangeError] naming [name] unless [value] is finite; otherwise null.
RangeError? _finiteError(double value, String name) {
  if (value.isFinite) return null;
  return RangeError.value(value, name, 'Must be finite');
}

/// An [ArgumentError] naming [name] unless every side of [insets] is finite
/// and not negative; otherwise null.
ArgumentError? _insetsError(EdgeInsets insets, String name) {
  final sides = [insets.left, insets.top, insets.right, insets.bottom];
  if (sides.every((side) => side >= 0 && side.isFinite)) return null;
  return ArgumentError.value(insets, name, 'Must be finite and not negative');
}

/// An [ArgumentError] naming [name] unless both axes of every corner of
/// [borderRadius] are finite and not negative; otherwise null.
ArgumentError? _radiusError(BorderRadius borderRadius, String name) {
  final axes = [
    for (final corner in [
      borderRadius.topLeft,
      borderRadius.topRight,
      borderRadius.bottomLeft,
      borderRadius.bottomRight,
    ]) ...[corner.x, corner.y],
  ];
  if (axes.every((axis) => axis >= 0 && axis.isFinite)) return null;
  return ArgumentError.value(
    borderRadius,
    name,
    'Must be finite and not negative',
  );
}

/// Calls [onPaint] each time it paints, so the calendar knows it was drawn.
class _OnScreenProbe extends SingleChildRenderObjectWidget {
  const _OnScreenProbe({required this.onPaint, super.child});

  final VoidCallback onPaint;

  @override
  _RenderOnScreenProbe createRenderObject(BuildContext context) {
    return _RenderOnScreenProbe(onPaint);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderOnScreenProbe renderObject,
  ) {
    renderObject.onPaint = onPaint;
  }
}

class _RenderOnScreenProbe extends RenderProxyBox {
  _RenderOnScreenProbe(this.onPaint);

  VoidCallback onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint();
    super.paint(context, offset);
  }
}
