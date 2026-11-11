import 'dart:math' as math;

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
/// update. From that update onward each move along the axis reports the turn
/// the drag gives the page and the finger start it is drawn with:
/// [_HeldTurn] for a next-month drag gripped on the page, [_BoxTurn] for any
/// other.
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

  /// Called on each move along the axis with the turn the drag gives the
  /// page, from 0 to 1, and the finger start it is drawn with.
  final void Function(double turn, double fingerStart) onDragProgress;

  /// Called once when a drag that began ends: whether it completes.
  final void Function(bool shouldComplete) onDragComplete;

  /// Sets the drag box and its curve, the progress threshold, the flick
  /// speed, and the page-turn style a drag that holds the page turns with.
  final CalendarStyle style;

  @override
  State<CalendarGestureHandler> createState() => _CalendarGestureHandlerState();
}

class _CalendarGestureHandlerState extends State<CalendarGestureHandler> {
  /// This widget's size along the swipe axis, from its last layout: the
  /// page's length.
  double _extent = 0;

  /// Where the drag was accepted, in this widget's coordinates: set by
  /// [_onDragStart], which Flutter calls when it accepts a drag, before the
  /// drag's first update.
  late Offset _accepted;

  /// How the drag turns the page, from its first delivered axis update; null
  /// when no drag is active.
  _SwipeTurn? _swipe;

  /// Whether updates are ignored after a drag is dropped or its axis has
  /// no size. A new pointer-down clears this flag.
  bool _ignoring = false;

  /// The style's flick speed at this widget's size, in pixels per second.
  double get _flickSpeed {
    final style = widget.style;
    return style.flickDistanceThreshold *
        _extent *
        Duration.microsecondsPerSecond /
        style.flickMaxDuration.inMicroseconds;
  }

  void _onDragDown(DragDownDetails details) {
    _ignoring = false;
  }

  void _onDragStart(DragStartDetails details) {
    _accepted = details.localPosition;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta!;
    // A move with no motion along the axis has no direction to read.
    if (_ignoring || delta == 0) return;
    final swipe = _swipe ??= _begin(delta);
    final turn = swipe.move(delta, _extent, widget.style);
    widget.onDragProgress(turn, swipe.fingerStart);
  }

  /// Reports the direction of the drag whose first move along the axis is
  /// [delta], and returns how it turns the page: a next-month drag gripped
  /// on the page holds it, any other turns through the box.
  _SwipeTurn _begin(double delta) {
    final next = widget.boundEdge.isNextGesture(delta);
    widget.onDragBegin(next ? DragDirection.next : DragDirection.previous);
    final accepted = _fromHinge(_accepted) / _extent;
    return next && accepted > 0
        ? _HeldTurn(delta.sign, accepted)
        : _BoxTurn(delta.sign);
  }

  /// How far [position], in this widget's coordinates, is from the bound
  /// edge along the axis, in logical pixels: negative past it.
  double _fromHinge(Offset position) {
    final edge = widget.boundEdge;
    final along = edge.isVerticalAxis ? position.dy : position.dx;
    return edge.requiresCoordinateFlip ? _extent - along : along;
  }

  void _onDragEnd(DragEndDetails details) {
    final swipe = _swipe;
    // A drag that never began (a tap, a move only across the axis) has
    // nothing to end.
    if (swipe == null) return;
    // Flutter's fling filter, set up in build, gives 0 for a release that is
    // not a flick.
    final velocity = details.primaryVelocity!;
    final completes = velocity != 0
        ? velocity.sign == swipe.sign
        : swipe.completes(_extent, widget.style);
    _swipe = null;
    widget.onDragComplete(completes);
  }

  /// A cancelled pointer ends its drag without completing it. The recognizer
  /// then ends the drag as a release, which finds no drag.
  void _onPointerCancel() {
    if (_swipe == null) return;
    _swipe = null;
    widget.onDragComplete(false);
  }

  @override
  void didUpdateWidget(CalendarGestureHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.boundEdge != oldWidget.boundEdge ||
        widget.enabled != oldWidget.enabled) {
      _swipe = null;
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
          if (_swipe != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => widget.onDragComplete(false),
            );
          }
          _swipe = null;
          _ignoring = true;
        }
        // The device's touch slop, as GestureDetector passes it.
        final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);

        void configure(DragGestureRecognizer recognizer) {
          recognizer
            ..gestureSettings = gestureSettings
            ..onlyAcceptDragOnThreshold = true
            // The movement made before the drag is accepted is discarded:
            // the page rises from flat under the finger, gripped where the
            // drag is accepted.
            ..dragStartBehavior = DragStartBehavior.start
            // A flick is a release at more than the style's speed, with
            // Flutter's standard minimum distance.
            ..minFlingVelocity = _flickSpeed
            ..onDown = _onDragDown
            ..onStart = _onDragStart
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

/// How a drag turns the page, from its first move along the axis to its end.
sealed class _SwipeTurn {
  _SwipeTurn(this.sign);

  /// The sign of a move in the drag's direction along the axis.
  final double sign;

  /// The finger start the turn is drawn with.
  double get fingerStart;

  /// Moves the drag [delta] logical pixels along the axis, on a page [length]
  /// long, styled by [style], and returns the turn it then gives the page,
  /// from 0 to 1.
  double move(double delta, double length, CalendarStyle style);

  /// Whether a release that is not a flick completes the drag, on a page
  /// [length] long, styled by [style].
  bool completes(double length, CalendarStyle style);
}

/// A drag that turns the page through the drag box, from its free edge.
/// Travel past either end of the box is discarded, so the page follows a
/// reversal at once.
final class _BoxTurn extends _SwipeTurn {
  _BoxTurn(super.sign);

  /// The distance moved in the drag's direction, kept within the box.
  double _moved = 0;

  @override
  double move(double delta, double length, CalendarStyle style) {
    _moved = (_moved + delta * sign).clamp(0.0, _box(length, style));
    return style.dragCurve.transform(_progress(length, style));
  }

  @override
  double get fingerStart => PageTurnInputs.standardFingerStart;

  @override
  bool completes(double length, CalendarStyle style) =>
      _progress(length, style) >= style.dragProgressThreshold;

  /// The box: the distance along the axis that turns the page all the way.
  static double _box(double length, CalendarStyle style) =>
      length * style.dragBoxFraction;

  /// The distance moved, as a share of the box.
  double _progress(double length, CalendarStyle style) =>
      _moved / _box(length, style);
}

/// A next-month drag that holds the paper under its grip, turned with
/// [PageTurnDragProgress] so that paper follows the finger.
///
/// Places are shares of the page from the hinge. The finger moves by each
/// update's delta, not to its position: Flutter reports a trackpad pan's
/// position offset by the widget's own. While the page lies flat, the grip
/// follows the finger away from the hinge, up to the free edge. For a grip
/// nearer the hinge than the package can hold
/// ([PageTurnInputs.maxFingerStart]), the nearest paper it can hold moves
/// faster than the finger, as much faster as brings it to the hinge with the
/// finger, but at most [CalendarStyle.nearEdgeMaxSpeedUp] times as fast.
final class _HeldTurn extends _SwipeTurn {
  /// A drag accepted at [accepted], a place above 0: past the free edge the
  /// page lies flat until the finger is back over it.
  _HeldTurn(super.sign, double accepted)
    : _finger = accepted,
      _grip = math.min(accepted, 1.0);

  /// The nearest place to the hinge the package can hold.
  static const double _nearestPaper = 1 - PageTurnInputs.maxFingerStart;

  /// The grip's place: above 0, at most 1.
  double _grip;

  /// The finger's place.
  double _finger;

  /// The turn's mapping, built when the page leaves flat and again when its
  /// finger start, the page's length or its style changes.
  PageTurnDragProgress? _drag;

  /// The last turn reported, where the search for the next one starts.
  double _turn = 0;

  /// The place of the paper held.
  double get _paper => math.max(_grip, _nearestPaper);

  /// The finger's travel toward the hinge since the grip.
  double get _travel => _grip - _finger;

  @override
  double move(double delta, double length, CalendarStyle style) {
    _finger -= delta * sign / length;
    _grip = math.min(math.max(_grip, _finger), 1.0);
    if (_travel <= 0) return _turn = 0;
    var drag = _drag;
    if (drag == null ||
        drag.pageLength != length ||
        drag.style != style.pageTurnStyle ||
        drag.fingerStart != fingerStart) {
      drag = _drag = PageTurnDragProgress(
        pageLength: length,
        style: style.pageTurnStyle,
        fingerStart: fingerStart,
      );
    }
    return _turn = drag.progressFor(
      _speedUp(style) * _travel * length,
      current: _turn,
    );
  }

  @override
  double get fingerStart => 1 - _paper;

  @override
  bool completes(double length, CalendarStyle style) =>
      _travel >= style.dragProgressThreshold * _paper / _speedUp(style);

  /// How many times the finger's speed the paper held moves: once, unless
  /// the grip is nearer the hinge than the paper held, and then as much faster
  /// as brings the paper to the hinge with the finger, at most the style's
  /// [CalendarStyle.nearEdgeMaxSpeedUp].
  double _speedUp(CalendarStyle style) =>
      math.min(_paper / _grip, style.nearEdgeMaxSpeedUp);
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
