import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

import '../style/calendar_haptic_type.dart';
import '../style/calendar_style.dart';
import '../utils/date_utils.dart';
import 'calendar_gesture_handler.dart';
import 'image_capture.dart';
import 'multi_month_animation_mode.dart';
import 'page_flip_renderer.dart';

/// Internal animation phases — replaces scattered boolean flags.
enum _Phase { idle, capturing, animating }

/// Internal widget that wraps calendar content with animation support.
///
/// Handles image capture, gesture-driven navigation, programmatic navigation,
/// and coordination between them. Delegates rendering to [PageFlipRenderer],
/// capture to [ImageCapture], and gestures to [CalendarGestureHandler].
class FlipCalendarWrapper extends StatefulWidget {
  const FlipCalendarWrapper({
    required this.child,
    required this.currentMonth,
    required this.onMonthChanged,
    required this.style,
    required this.boundEdge,
    required this.maxAnimatedMonthJump,
    required this.multiMonthAnimationMode,
    required this.animationsEnabled,
    required this.gesturesEnabled,
    required this.buildCalendarForMonth,
    this.minDate,
    this.maxDate,
    this.onHapticFeedback,
    this.onAnimationStateChanged,
    super.key,
  });

  final Widget child;
  final DateTime currentMonth;
  final void Function(DateTime newMonth) onMonthChanged;
  final CalendarStyle style;
  final PageTurnEdge boundEdge;
  final DateTime? minDate;
  final DateTime? maxDate;
  final int maxAnimatedMonthJump;
  final MultiMonthAnimationMode multiMonthAnimationMode;
  final bool animationsEnabled;
  final bool gesturesEnabled;
  final Widget Function(DateTime month) buildCalendarForMonth;
  final void Function(CalendarHapticType type)? onHapticFeedback;
  final void Function(bool isAnimating)? onAnimationStateChanged;

  @override
  FlipCalendarWrapperState createState() => FlipCalendarWrapperState();
}

class FlipCalendarWrapperState extends State<FlipCalendarWrapper>
    with TickerProviderStateMixin {
  // Animation
  late AnimationController _flipController;
  late CurvedAnimation _flipCurve;

  // Image capture keys
  final GlobalKey _currentKey = GlobalKey();
  final GlobalKey _targetKey = GlobalKey();

  // Captured images
  ui.Image? _currentImage;
  ui.Image? _targetImage;

  // Phase state — the core simplification over the old boolean soup
  _Phase _phase = _Phase.idle;
  bool _isForward = true;
  bool _isGestureControlled = false;
  bool _expectingGestureMonthChange = false;
  double _maxProgressAllowed = 1.0;
  static const double _restrictedMaxProgress = 0.02;

  // Widgets for capture phase
  Widget? _oldChild;
  Widget? _newChild;

  // Override for displaying intermediate months during sequential animation
  Widget? _displayChild;

  // Gesture tracking: handles drag ending before capture completes
  bool _dragActive = false;
  bool?
  _pendingGestureResult; // true = complete, false = cancel, null = still dragging

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: widget.style.animationDuration,
      vsync: this,
    );
    _flipCurve = CurvedAnimation(
      parent: _flipController,
      curve: widget.style.animationCurve,
    );
  }

  @override
  void didUpdateWidget(FlipCalendarWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update animation config if style changed
    if (widget.style.animationDuration != oldWidget.style.animationDuration) {
      _flipController.duration = widget.style.animationDuration;
    }
    if (widget.style.animationCurve != oldWidget.style.animationCurve) {
      _flipCurve.dispose();
      _flipCurve = CurvedAnimation(
        parent: _flipController,
        curve: widget.style.animationCurve,
      );
    }

    // If we're expecting a month change from a completed gesture, absorb it
    if (_expectingGestureMonthChange) {
      _expectingGestureMonthChange = false;
      return;
    }

    // Detect programmatic month change — only when idle
    if (_phase == _Phase.idle &&
        !_isGestureControlled &&
        !CalendarDateUtils.isSameMonth(
          widget.currentMonth,
          oldWidget.currentMonth,
        )) {
      _handleProgrammaticMonthChange(
        oldMonth: oldWidget.currentMonth,
        newMonth: widget.currentMonth,
      );
    }
  }

  @override
  void dispose() {
    if (_flipController.isAnimating) {
      try {
        _flipController.stop();
      } catch (_) {}
    }
    _flipCurve.dispose();
    _flipController.dispose();
    _disposeImages();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Animating state notification
  // ---------------------------------------------------------------------------

  bool _notificationScheduled = false;
  bool _lastNotifiedAnimating = false;
  bool _desiredAnimatingState = false;

  void _setAnimating(bool animating) {
    // Store the latest desired state
    _desiredAnimatingState = animating;
    // Defer notification to post-frame to avoid setState-during-build.
    // Coalesces rapid true→false transitions into a single notification.
    if (!_notificationScheduled) {
      _notificationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        // Read the latest desired state now (not from closure)
        if (mounted && _desiredAnimatingState != _lastNotifiedAnimating) {
          _lastNotifiedAnimating = _desiredAnimatingState;
          widget.onAnimationStateChanged?.call(_desiredAnimatingState);
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Programmatic navigation
  // ---------------------------------------------------------------------------

  void _handleProgrammaticMonthChange({
    required DateTime oldMonth,
    required DateTime newMonth,
  }) {
    if (!widget.animationsEnabled) {
      return; // Widget already shows the new month via widget.child
    }

    _isForward = newMonth.isAfter(oldMonth);
    final oldChild = widget.buildCalendarForMonth(oldMonth);

    _animateTransition(
      startChild: oldChild,
      endChild: widget.child,
      startMonth: oldMonth,
      endMonth: newMonth,
    );
  }

  Future<void> _animateTransition({
    required Widget startChild,
    required Widget endChild,
    required DateTime startMonth,
    required DateTime endMonth,
  }) async {
    final delta = CalendarDateUtils.monthsDelta(startMonth, endMonth).abs();
    final useDirectJump =
        widget.multiMonthAnimationMode == MultiMonthAnimationMode.directJump;

    // In sequential mode, skip animation for large jumps
    if (!useDirectJump && delta > widget.maxAnimatedMonthJump) {
      return;
    }

    _setAnimating(true);

    try {
      if (useDirectJump || delta == 1) {
        _flipController.duration = widget.style.animationDuration;
        await _flipOnce(startChild, endChild);
      } else {
        await _flipSequential(
          startChild,
          endChild,
          startMonth,
          endMonth,
          delta,
        );
      }
    } finally {
      _setAnimating(false);
      if (mounted) {
        setState(() {
          _displayChild = null;
          _phase = _Phase.idle;
        });
        _disposeImages();
      }
    }
  }

  /// Single page flip from [oldChild] to [newChild].
  Future<void> _flipOnce(Widget oldChild, Widget newChild) async {
    // 1. Set up capture phase
    setState(() {
      _oldChild = oldChild;
      _newChild = newChild;
      _phase = _Phase.capturing;
    });

    // 2. Wait for RepaintBoundaries to render
    await _waitForFrame();

    // 3. Capture images
    final success = await _captureImages();
    if (!success || !mounted) return;

    // 4. Switch to animation phase
    setState(() => _phase = _Phase.animating);

    // 5. Run animation
    try {
      await _flipController.forward();
    } catch (_) {} // Animation may fail if disposed

    if (!mounted) return;

    _flipController.reset();
    _disposeImages();
  }

  /// Sequential flip through each intermediate month.
  Future<void> _flipSequential(
    Widget startChild,
    Widget endChild,
    DateTime startMonth,
    DateTime endMonth,
    int delta,
  ) async {
    // Divide duration across all steps
    final perStep = (widget.style.animationDuration.inMilliseconds / delta)
        .round();
    _flipController.duration = Duration(milliseconds: perStep);

    DateTime currentMonth = startMonth;
    Widget currentChild = startChild;

    for (int i = 0; i < delta; i++) {
      if (!mounted) return;

      final nextMonth = _isForward
          ? DateTime(currentMonth.year, currentMonth.month + 1)
          : DateTime(currentMonth.year, currentMonth.month - 1);

      final isLast = (i == delta - 1);
      final nextChild = isLast
          ? endChild
          : widget.buildCalendarForMonth(nextMonth);

      await _flipOnce(currentChild, nextChild);

      if (!isLast && mounted) {
        setState(() => _displayChild = nextChild);
        currentMonth = nextMonth;
        currentChild = nextChild;
      }
    }

    // Restore normal duration
    _flipController.duration = widget.style.animationDuration;
  }

  // ---------------------------------------------------------------------------
  // Gesture navigation
  // ---------------------------------------------------------------------------

  void _onDragBegin(DragDirection direction) {
    if (_phase != _Phase.idle || _isGestureControlled) return;

    _dragActive = true;
    _pendingGestureResult = null;
    _isGestureControlled = true;
    _isForward = (direction == DragDirection.next);

    final targetMonth = _isForward
        ? DateTime(widget.currentMonth.year, widget.currentMonth.month + 1)
        : DateTime(widget.currentMonth.year, widget.currentMonth.month - 1);

    // Check date bounds
    final isRestricted = !CalendarDateUtils.isMonthNavigable(
      targetMonth,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
    );

    if (isRestricted) {
      widget.onHapticFeedback?.call(CalendarHapticType.navigationRestricted);
    }

    setState(() {
      _maxProgressAllowed = isRestricted ? _restrictedMaxProgress : 1.0;
      _oldChild = widget.child;
      _newChild = widget.buildCalendarForMonth(targetMonth);
      _phase = _Phase.capturing;
    });

    _setAnimating(true);

    // Start async capture
    _prepareGestureImages();
  }

  Future<void> _prepareGestureImages() async {
    await _waitForFrame();
    final success = await _captureImages();

    if (!mounted) return;

    if (!success) {
      _cleanupGesture();
      return;
    }

    // Images captured — switch to animation phase
    setState(() => _phase = _Phase.animating);

    // If drag already ended while we were capturing, handle it now
    if (_pendingGestureResult != null) {
      if (_pendingGestureResult!) {
        _completeGesture();
      } else {
        _cancelGesture();
      }
    } else if (!_dragActive) {
      // Drag ended without setting a result (e.g., lifted before any
      // meaningful movement) — clean up to avoid getting stuck.
      _cleanupGesture();
    }
  }

  void _onDragProgress(double progress) {
    if (!_isGestureControlled) return;
    // Set controller value — visible only once phase == animating
    _flipController.value = progress;
  }

  void _onDragComplete(bool shouldComplete) {
    _dragActive = false;

    if (!_isGestureControlled) return;

    if (_phase == _Phase.animating) {
      // Images ready — handle immediately
      if (shouldComplete) {
        _completeGesture();
      } else {
        _cancelGesture();
      }
    } else {
      // Still capturing — defer
      _pendingGestureResult = shouldComplete;
    }
  }

  Future<void> _completeGesture() async {
    _expectingGestureMonthChange = true;

    // Notify parent of month change
    final targetMonth = _isForward
        ? DateTime(widget.currentMonth.year, widget.currentMonth.month + 1)
        : DateTime(widget.currentMonth.year, widget.currentMonth.month - 1);
    widget.onMonthChanged(targetMonth);

    // Complete the animation from current position
    try {
      await _flipController.forward(from: _flipController.value);
    } catch (_) {}

    _cleanupGesture();
  }

  Future<void> _cancelGesture() async {
    // Snap back from current position
    try {
      await _flipController.reverse(from: _flipController.value);
    } catch (_) {}

    _cleanupGesture();
  }

  void _cleanupGesture() {
    if (!mounted) return;
    setState(() {
      _isGestureControlled = false;
      _phase = _Phase.idle;
      _oldChild = null;
      _newChild = null;
      _pendingGestureResult = null;
      _maxProgressAllowed = 1.0;
    });
    _setAnimating(false);
    _flipController.reset();
    _disposeImages();
  }

  // ---------------------------------------------------------------------------
  // Image capture helpers
  // ---------------------------------------------------------------------------

  Future<bool> _captureImages() async {
    if (!mounted) return false;

    // Dispose any previously held images before capturing new ones.
    // Prevents a transient leak if a prior capture partially succeeded
    // (e.g., during sequential animation retries).
    _disposeImages();

    final pixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;

    // Capture current month
    final currentBoundary =
        _currentKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (currentBoundary != null) {
      _currentImage = await ImageCapture.capture(currentBoundary, pixelRatio);
    }

    // Capture target month
    final targetBoundary =
        _targetKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (targetBoundary != null) {
      _targetImage = await ImageCapture.capture(targetBoundary, pixelRatio);
    }

    return _currentImage != null && _targetImage != null;
  }

  void _disposeImages() {
    try {
      _currentImage?.dispose();
    } catch (_) {}
    try {
      _targetImage?.dispose();
    } catch (_) {}
    _currentImage = null;
    _targetImage = null;
  }

  Future<void> _waitForFrame() async {
    await SchedulerBinding.instance.endOfFrame;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final content = _buildForPhase();

    if (widget.animationsEnabled && widget.gesturesEnabled) {
      return CalendarGestureHandler(
        boundEdge: widget.boundEdge,
        isAnimating: _phase != _Phase.idle && !_isGestureControlled,
        maxProgressAllowed: _maxProgressAllowed,
        style: widget.style,
        onDragBegin: _onDragBegin,
        onDragProgress: _onDragProgress,
        onDragComplete: _onDragComplete,
        child: content,
      );
    }

    return content;
  }

  Widget _buildForPhase() {
    switch (_phase) {
      case _Phase.capturing:
        // Render both months for image capture, current on top
        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                key: _targetKey,
                child: _newChild ?? widget.child,
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                key: _currentKey,
                child: _oldChild ?? _displayChild ?? widget.child,
              ),
            ),
          ],
        );

      case _Phase.animating:
        return PageFlipRenderer.build(
          destinationChild: _newChild ?? _displayChild ?? widget.child,
          currentImage: _currentImage,
          targetImage: _targetImage,
          animation: _flipCurve,
          isForward: _isForward,
          boundEdge: widget.boundEdge,
          pageTurnStyle: widget.style.pageTurnStyle,
        );

      case _Phase.idle:
        return _displayChild ?? widget.child;
    }
  }
}
