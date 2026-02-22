import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Utility for capturing widget snapshots as [ui.Image].
///
/// Isolated from widget state — given a [RenderRepaintBoundary],
/// returns an image or null on failure.
class ImageCapture {
  ImageCapture._();

  static const int _maxRetries = 3;

  /// Captures the content of a [RenderRepaintBoundary] as a [ui.Image].
  ///
  /// Returns null if capture fails after [_maxRetries] attempts.
  /// The caller is responsible for disposing the returned image.
  static Future<ui.Image?> capture(
    RenderRepaintBoundary boundary,
    double pixelRatio,
  ) async {
    try {
      // Flush the render pipeline to ensure content is painted
      RendererBinding.instance.rootPipelineOwner.flushLayout();
      RendererBinding.instance.rootPipelineOwner.flushCompositingBits();
      RendererBinding.instance.rootPipelineOwner.flushPaint();

      // Wait for two frames to ensure everything is settled
      await _waitForFrame();
      await _waitForFrame();

      if (!boundary.hasSize) return null;

      for (int attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          final image = await boundary.toImage(pixelRatio: pixelRatio);
          if (image.width > 0 && image.height > 0) {
            return image;
          }
          image.dispose();
        } catch (_) {
          if (attempt == _maxRetries - 1) return null;
          await _waitForFrame();
        }
      }
    } catch (_) {
      // Silently fail — caller handles null gracefully
    }
    return null;
  }

  /// Waits for the next frame to complete.
  static Future<void> _waitForFrame() {
    final completer = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    SchedulerBinding.instance.scheduleFrame();
    return completer.future;
  }
}
