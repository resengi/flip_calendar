import 'package:page_turn_animation/page_turn_animation.dart';

/// Extensions on [PageTurnEdge] for gesture handling.
extension PageTurnEdgeGestures on PageTurnEdge {
  /// Whether this edge uses vertical gestures (top/bottom).
  bool get isVertical =>
      this == PageTurnEdge.top || this == PageTurnEdge.bottom;

  /// Whether this edge uses horizontal gestures (left/right).
  bool get isHorizontal =>
      this == PageTurnEdge.left || this == PageTurnEdge.right;

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
