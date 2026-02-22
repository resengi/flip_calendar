import 'package:flutter/material.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

import '../style/calendar_style.dart';
import '../utils/page_turn_edge_extensions.dart';

/// Direction of a drag gesture relative to month navigation.
enum DragDirection { next, previous }

/// Translates swipe gestures into navigation callbacks.
///
/// Supports vertical gestures (top/bottom edges) and horizontal gestures
/// (left/right edges). Emits three lifecycle callbacks:
/// [onDragBegin], [onDragProgress], [onDragComplete].
class CalendarGestureHandler extends StatefulWidget {
  const CalendarGestureHandler({
    required this.child,
    required this.boundEdge,
    required this.onDragBegin,
    required this.onDragProgress,
    required this.onDragComplete,
    required this.isAnimating,
    required this.style,
    this.maxProgressAllowed = 1.0,
    super.key,
  });

  final Widget child;
  final PageTurnEdge boundEdge;
  final void Function(DragDirection direction)? onDragBegin;
  final void Function(double progress)? onDragProgress;
  final void Function(bool shouldComplete)? onDragComplete;
  final bool isAnimating;
  final CalendarStyle style;
  final double maxProgressAllowed;

  @override
  CalendarGestureHandlerState createState() => CalendarGestureHandlerState();
}

class CalendarGestureHandlerState extends State<CalendarGestureHandler> {
  double? _startPosition;
  double? _initialPositionInCurrentDirection;
  double? _currentPosition;
  DragDirection? _initialDirection;
  DragDirection? _currentDirection;

  // Threshold values computed from widget size
  double _flickThresholdPx = 0;
  double _dragThresholdPx = 0;
  double _thresholdVelocity = 0;
  Size _lastKnownSize = Size.zero;

  bool _isDragging = false;
  double _progress = 0;
  static const double _minimumFlickDistancePx = 5.0;

  void _resetState() {
    _startPosition = null;
    _initialPositionInCurrentDirection = null;
    _currentPosition = null;
    _initialDirection = null;
    _currentDirection = null;
    _isDragging = false;
    _progress = 0;
  }

  double _getRelevantDimension(Size size) {
    return widget.boundEdge.isVertical ? size.height : size.width;
  }

  void _updateThresholds(Size size) {
    if (size == _lastKnownSize) return;
    _lastKnownSize = size;

    final dimension = _getRelevantDimension(size);
    _flickThresholdPx = dimension * widget.style.flickDistanceThreshold;
    _dragThresholdPx = dimension * widget.style.dragBoxSizePercentage;
    _thresholdVelocity =
        1000 * _flickThresholdPx / widget.style.flickMaxDuration.inMilliseconds;
  }

  // -- Position extraction (axis depends on bound edge) --

  double _positionFrom(Offset globalPosition) {
    return widget.boundEdge.isVertical ? globalPosition.dy : globalPosition.dx;
  }

  double _deltaFrom(Offset delta) {
    return widget.boundEdge.isVertical ? delta.dy : delta.dx;
  }

  DragDirection _directionFrom(double delta) {
    return widget.boundEdge.isNextGesture(delta)
        ? DragDirection.next
        : DragDirection.previous;
  }

  // -- Gesture callbacks --

  void _onDragStart(DragStartDetails details) {
    if (widget.isAnimating) return;
    _currentPosition = _positionFrom(details.globalPosition);
    _startPosition = _currentPosition;
    _initialPositionInCurrentDirection = _currentPosition;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (widget.isAnimating) return;

    try {
      final delta = _deltaFrom(details.delta);
      final draggedDirection = _directionFrom(delta);

      _initialDirection ??= draggedDirection;
      _currentPosition = _positionFrom(details.globalPosition);

      // Track direction changes
      if (draggedDirection != _currentDirection) {
        _initialPositionInCurrentDirection = _currentPosition;
        _currentDirection = draggedDirection;
      }

      if (_isDragging) {
        final totalDistance = (_startPosition! - _currentPosition!).abs();

        // Check if we're still on the correct side of the start position.
        // This allows progress to naturally decrease as the user drags back
        // toward start, only resetting when they cross past the start point.
        final displacement = _currentPosition! - _startPosition!;
        final isStillInInitialSide =
            displacement == 0 ||
            (_initialDirection == DragDirection.next) ==
                widget.boundEdge.isNextGesture(displacement);

        if (isStillInInitialSide) {
          _progress = (_dragThresholdPx > 0)
              ? (totalDistance / _dragThresholdPx).clamp(
                  0.0,
                  widget.maxProgressAllowed,
                )
              : 0.0;
        } else {
          _startPosition = _currentPosition;
          _progress = 0.0;
        }
        widget.onDragProgress?.call(_progress);
      } else {
        _isDragging = true;
        widget.onDragBegin?.call(draggedDirection);
      }
    } catch (err, stack) {
      _resetState();
      FlutterError.reportError(
        FlutterErrorDetails(exception: err, stack: stack),
      );
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (widget.isAnimating) return;

    try {
      if (_startPosition == null || _currentPosition == null) return;

      final velocity = details.primaryVelocity?.abs() ?? 0;
      final distance = _currentPosition! - _initialPositionInCurrentDirection!;

      // Flick: high velocity + some distance + same direction + not restricted
      if (velocity >= _thresholdVelocity &&
          distance.abs() >= _minimumFlickDistancePx) {
        final dir = _directionFrom(distance);
        if (_initialDirection == dir && widget.maxProgressAllowed == 1.0) {
          widget.onDragComplete?.call(true);
        } else {
          widget.onDragComplete?.call(false);
        }
      } else {
        // Drag threshold check
        widget.onDragComplete?.call(
          _progress >= widget.style.dragProgressThreshold,
        );
      }
    } finally {
      _resetState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveSize =
            (constraints.hasBoundedWidth && constraints.hasBoundedHeight)
            ? Size(constraints.maxWidth, constraints.maxHeight)
            : MediaQuery.of(context).size;

        _updateThresholds(effectiveSize);

        final isVertical = widget.boundEdge.isVertical;
        final enabled = !widget.isAnimating;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: isVertical && enabled ? _onDragStart : null,
          onVerticalDragUpdate: isVertical && enabled ? _onDragUpdate : null,
          onVerticalDragEnd: isVertical && enabled ? _onDragEnd : null,
          onHorizontalDragStart: !isVertical && enabled ? _onDragStart : null,
          onHorizontalDragUpdate: !isVertical && enabled ? _onDragUpdate : null,
          onHorizontalDragEnd: !isVertical && enabled ? _onDragEnd : null,
          child: widget.child,
        );
      },
    );
  }
}
