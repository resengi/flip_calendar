import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

/// Builds the visual layer stack for a page-turn animation.
///
/// This is purely a rendering helper — no state management, no lifecycle.
/// Given captured images and an animation, it returns the correct widget tree.
class PageFlipRenderer {
  PageFlipRenderer._();

  /// Builds the page-flip widget stack.
  ///
  /// [destinationChild] is the live widget shown underneath the animation.
  /// [currentImage] is the snapshot of the month being navigated away from.
  /// [targetImage] is the snapshot of the month being navigated to.
  /// [animation] drives the page-turn effect.
  /// [isForward] controls direction — true = current flips away, false =
  ///   target flips in.
  /// [boundEdge] determines which edge the page turns from.
  /// [pageTurnStyle] configures the curl effect.
  static Widget build({
    required Widget destinationChild,
    required ui.Image? currentImage,
    required ui.Image? targetImage,
    required Animation<double> animation,
    required bool isForward,
    required PageTurnEdge boundEdge,
    required PageTurnStyle pageTurnStyle,
  }) {
    return Stack(
      children: [
        // Bottom layer: the live destination widget
        Positioned.fill(child: destinationChild),

        // Forward: current month image flips away
        if (isForward && currentImage != null)
          PageTurnAnimation(
            image: currentImage,
            animation: animation,
            direction: PageTurnDirection.forward,
            edge: boundEdge,
            style: pageTurnStyle,
          ),

        // Backward: static current image hides destination,
        // target image flips in on top
        if (!isForward) ...[
          if (currentImage != null)
            Positioned.fill(
              child: RawImage(
                image: currentImage,
                fit: BoxFit.fill,
              ),
            ),
          if (targetImage != null)
            PageTurnAnimation(
              image: targetImage,
              animation: animation,
              direction: PageTurnDirection.backward,
              edge: boundEdge,
              style: pageTurnStyle,
            ),
        ],
      ],
    );
  }
}
