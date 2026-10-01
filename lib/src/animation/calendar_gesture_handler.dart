import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

import '../style/calendar_style.dart';

/// Direction of a drag gesture relative to month navigation.
enum DragDirection { next, previous }

/// Turns one-finger drags on [child] along the swipe axis into a swipe's
/// begin, progress and end.
///
/// The top and bottom edges take vertical drags, the left and right edges
/// horizontal ones. A drag follows the pointer that started it; other
/// pointers are ignored until it lifts. The drag begins on its first move
/// along the axis, whose direction is the drag's ([onDragBegin]). Each move
/// along the axis, the first included, reports the drag's progress
/// ([onDragProgress]): the distance the finger has moved along the axis since
/// it went down, in this widget's coordinates and in the drag's direction,
/// over [CalendarStyle.dragBoxSizePercentage] of this widget's size along the
/// axis, from 0 to 1. Back past the start it is 0.
///
/// A drag that began reports one end ([onDragComplete]); a tap, or a move
/// only across the axis, reports nothing. A flick in the drag's direction
/// completes it and a flick against it does not; without a flick, it
/// completes when its progress is at least
/// [CalendarStyle.dragProgressThreshold]. A flick is a release that Flutter's
/// fling filter accepts, with its minimum speed set to
/// [CalendarStyle.flickDistanceThreshold] of this widget's size along the
/// axis per [CalendarStyle.flickMaxDuration], and its standard minimum
/// distance (the touch slop, for a finger).
///
/// A cancelled pointer ends the drag without completing it. When this widget
/// has no size along the axis, the drag ends without completing once that
/// frame is done; when [boundEdge] changes, it is dropped without an end. In
/// both cases the rest of the drag is ignored.
class CalendarGestureHandler extends StatefulWidget {
  const CalendarGestureHandler({
    required this.child,
    required this.boundEdge,
    required this.onDragBegin,
    required this.onDragProgress,
    required this.onDragComplete,
    required this.style,
    super.key,
  });

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

  /// The sign of the drag's direction along the axis, taken from its first
  /// move along the axis: 0 while no drag has begun.
  double _sign = 0;

  /// The distance moved along the axis since the pointer went down, in this
  /// widget's coordinates.
  double _moved = 0;

  /// Whether the rest of the current pointer's drag is ignored: set when the
  /// handler collapses to no size along the axis or its bound edge changes,
  /// cleared when the next pointer goes down.
  bool _ignoring = false;

  /// The drag's progress: the distance moved in its direction over the drag
  /// box, from 0 to 1. Back past the start it is 0.
  double get _progress {
    final dragBox = _extent * widget.style.dragBoxSizePercentage;
    return (_moved * _sign / dragBox).clamp(0.0, 1.0);
  }

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
    _moved += delta;
    if (_sign == 0) {
      _sign = delta.sign;
      widget.onDragBegin(
        widget.boundEdge.isNextGesture(delta)
            ? DragDirection.next
            : DragDirection.previous,
      );
    }
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
    // A drag toward one edge means nothing toward another. The calendar ends
    // its swipe itself, so the rest of the drag is ignored without an end.
    if (widget.boundEdge != oldWidget.boundEdge) {
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
            // The movement made before the drag is accepted arrives as its
            // first update.
            ..dragStartBehavior = DragStartBehavior.down
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
            if (vertical)
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
            else
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
