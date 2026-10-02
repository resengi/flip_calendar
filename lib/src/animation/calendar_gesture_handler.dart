import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

import '../style/calendar_style.dart';

/// Direction of a drag gesture relative to month navigation.
enum DragDirection { next, previous }

/// Turns one-pointer drags on [child] into begin, progress and end reports.
///
/// Top and bottom bindings use the vertical axis; left and right bindings
/// use the horizontal axis. The starting pointer is followed until it ends.
/// A drag begins after Flutter accepts it and its drag threshold is crossed.
/// Its direction is the net movement along the axis in the first delivered
/// update. Progress is reported from that update onward and counts movement
/// from the point where the drag was accepted, measured in this widget's
/// coordinates. Progress is 0 to 1 over
/// [CalendarStyle.dragBoxSizePercentage] of the axis size. Travel past
/// either end of that box is discarded, so the page follows a reversal at
/// once: back past the start it rests at 0 until the finger moves on again.
///
/// A begun drag reports one end on release or pointer cancellation. A flick
/// in its direction completes it; an opposite flick cancels it. Other
/// releases complete at [CalendarStyle.dragProgressThreshold]. Flutter's
/// fling filter uses the configured speed and its minimum distance for the
/// pointer device.
///
/// Changing [enabled] or [boundEdge] drops the current drag without an end.
/// Collapsing to zero size along the axis ends it without completing after
/// the frame. Dropped movement is ignored until a new pointer begins.
class CalendarGestureHandler extends StatefulWidget {
  const CalendarGestureHandler({
    required this.child,
    required this.boundEdge,
    required this.onDragBegin,
    required this.onDragProgress,
    required this.onDragComplete,
    required this.style,
    this.enabled = true,
    super.key,
  });

  /// Whether this handler recognizes drags. Changing it drops the
  /// current drag without reporting an end.
  final bool enabled;

  /// The widget the drags are made on.
  final Widget child;

  /// The edge the pages are bound at. It sets the swipe axis, and a drag
  /// toward it is next.
  final PageTurnEdge boundEdge;

  /// Called when a drag begins, with its direction.
  final void Function(DragDirection direction) onDragBegin;

  /// Called with the drag's progress on each move along the axis.
  final void Function(double progress) onDragProgress;

  /// Called once when a drag that began ends: whether it completes.
  final void Function(bool shouldComplete) onDragComplete;

  /// Sets the drag box, the progress threshold and the flick speed.
  final CalendarStyle style;

  @override
  State<CalendarGestureHandler> createState() => _CalendarGestureHandlerState();
}

class _CalendarGestureHandlerState extends State<CalendarGestureHandler> {
  /// This widget's size along the swipe axis, from its last layout.
  double _extent = 0;

  /// The sign of the first delivered axis update, or 0 when no drag is active.
  double _sign = 0;

  /// The distance moved in the drag's direction since it was accepted, in
  /// this widget's coordinates, kept within the drag box: travel past either
  /// end is discarded.
  double _moved = 0;

  /// Whether updates are ignored after a drag is dropped or its axis has
  /// no size. A new pointer-down clears this flag.
  bool _ignoring = false;

  /// The drag box: the distance along the axis that turns the page all the
  /// way.
  double get _dragBox => _extent * widget.style.dragBoxSizePercentage;

  /// The drag's progress, from 0 to 1.
  double get _progress => _moved / _dragBox;

  /// The style's flick speed at this widget's size, in pixels per second.
  double get _flickSpeed {
    final style = widget.style;
    return style.flickDistanceThreshold *
        _extent *
        Duration.microsecondsPerSecond /
        style.flickMaxDuration.inMicroseconds;
  }

  void _onDragDown(DragDownDetails details) {
    _moved = 0;
    _ignoring = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta!;
    // A move with no motion along the axis has no direction to read.
    if (_ignoring || delta == 0) return;
    if (_sign == 0) {
      _sign = delta.sign;
      widget.onDragBegin(
        widget.boundEdge.isNextGesture(delta)
            ? DragDirection.next
            : DragDirection.previous,
      );
    }
    _moved = (_moved + delta * _sign).clamp(0.0, _dragBox);
    widget.onDragProgress(_progress);
  }

  void _onDragEnd(DragEndDetails details) {
    // A drag that never began (a tap, a move only across the axis) has
    // nothing to end.
    if (_sign == 0) return;
    // Flutter's fling filter, set up in build, gives 0 for a release that is
    // not a flick.
    final velocity = details.primaryVelocity!;
    final completes = velocity != 0
        ? velocity.sign == _sign
        : _progress >= widget.style.dragProgressThreshold;
    _sign = 0;
    widget.onDragComplete(completes);
  }

  /// A cancelled pointer ends its drag without completing it. The recognizer
  /// then ends the drag as a release, which finds no drag.
  void _onPointerCancel() {
    if (_sign == 0) return;
    _sign = 0;
    widget.onDragComplete(false);
  }

  @override
  void didUpdateWidget(CalendarGestureHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.boundEdge != oldWidget.boundEdge ||
        widget.enabled != oldWidget.enabled) {
      _sign = 0;
      _ignoring = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = widget.boundEdge.isVerticalAxis;
        _extent = vertical ? constraints.maxHeight : constraints.maxWidth;
        // With no size along the axis a drag has nothing to measure its
        // progress against: it ends without completing once this frame is
        // done, and the rest of it is ignored.
        if (_extent == 0) {
          if (_sign != 0) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => widget.onDragComplete(false),
            );
          }
          _sign = 0;
          _ignoring = true;
        }
        // The device's touch slop, as GestureDetector passes it.
        final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

        void configure(DragGestureRecognizer recognizer) {
          recognizer
            ..gestureSettings = gestureSettings
            ..onlyAcceptDragOnThreshold = true
            // The movement made before the drag is accepted is discarded:
            // the page rises from flat under the finger.
            ..dragStartBehavior = DragStartBehavior.start
            // A flick is a release at more than the style's speed, with
            // Flutter's standard minimum distance.
            ..minFlingVelocity = _flickSpeed
            ..onDown = _onDragDown
            ..onUpdate = _onDragUpdate
            ..onEnd = _onDragEnd;
        }

        return RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: {
            if (widget.enabled && vertical)
              _VerticalSwipeRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _VerticalSwipeRecognizer
                  >(
                    () => _VerticalSwipeRecognizer(
                      onPointerCancel: _onPointerCancel,
                      debugOwner: this,
                    ),
                    configure,
                  )
            else if (widget.enabled)
              _HorizontalSwipeRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _HorizontalSwipeRecognizer
                  >(
                    () => _HorizontalSwipeRecognizer(
                      onPointerCancel: _onPointerCancel,
                      debugOwner: this,
                    ),
                    configure,
                  ),
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Follows only the pointer that started a drag: other pointers are ignored
/// until it lifts. Reports a cancel of that pointer, which Flutter's drag
/// recognizers otherwise end as a release.
mixin _SwipeRecognizer on OneSequenceGestureRecognizer {
  /// Called when the followed pointer is cancelled, before the recognizer
  /// ends its drag.
  VoidCallback get onPointerCancel;

  /// Whether a pointer is being followed.
  bool _following = false;

  @override
  void addPointer(PointerDownEvent event) {
    if (!_following) super.addPointer(event);
  }

  @override
  void addPointerPanZoom(PointerPanZoomStartEvent event) {
    if (!_following) super.addPointerPanZoom(event);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _following = true;
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    super.addAllowedPointerPanZoom(event);
    _following = true;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerCancelEvent) onPointerCancel();
    super.handleEvent(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    _following = false;
  }
}

class _VerticalSwipeRecognizer extends VerticalDragGestureRecognizer
    with _SwipeRecognizer {
  _VerticalSwipeRecognizer({required this.onPointerCancel, super.debugOwner});

  @override
  final VoidCallback onPointerCancel;
}

class _HorizontalSwipeRecognizer extends HorizontalDragGestureRecognizer
    with _SwipeRecognizer {
  _HorizontalSwipeRecognizer({required this.onPointerCancel, super.debugOwner});

  @override
  final VoidCallback onPointerCancel;
}

/// Extensions on [PageTurnEdge] for gesture handling.
extension _PageTurnEdgeGestures on PageTurnEdge {
  /// Given a drag delta, returns `true` if the gesture navigates
  /// to the next month (i.e., swipes *toward* the bound edge).
  bool isNextGesture(double delta) {
    switch (this) {
      case PageTurnEdge.top:
        return delta < 0; // Swipe up → next
      case PageTurnEdge.bottom:
        return delta > 0; // Swipe down → next
      case PageTurnEdge.left:
        return delta < 0; // Swipe left → next
      case PageTurnEdge.right:
        return delta > 0; // Swipe right → next
    }
  }
}
