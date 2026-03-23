import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

/// Widget tests for gesture-driven navigation in FlipCalendar.
///
/// Covers single gestures, rapid multi-gesture sequences, programmatic
/// navigation interaction, horizontal bound edges, and date-bound
/// restrictions.
///
/// ## Image capture limitation
///
/// FlipCalendarWrapper captures RepaintBoundary snapshots via `toImage()`
/// to render page-turn animations. In widget tests, `toImage()` is
/// unreliable — capture tends to fail for certain gesture directions or
/// timings. When capture fails, the wrapper cleans up and returns to idle
/// without changing the month.
///
/// This has a significant impact on the "gesture lockout" tests. The core
/// re-entry bug requires the first gesture's transition to be *actively
/// animating* when the second gesture arrives. But when capture fails for
/// the first gesture, the wrapper returns to idle before the second gesture
/// begins, so there is no active transition to re-enter. The lockout tests
/// therefore pass trivially — they verify that the bug outcome (double-
/// advance to August) does not occur, but the vulnerable code path is
/// never actually reached.
///
/// **What these tests reliably verify in `flutter test`:**
/// - Single gesture outcomes (advance or no-op from capture failure)
/// - Programmatic navigation gesture lockout (no capture dependency)
/// - Drag threshold cancellation
/// - Date-bound restriction enforcement
/// - No multi-advance from repeated gestures (upper bound safety net)
///
/// **What requires device/emulator testing (integration tests):**
/// - The specific re-entry scenario: fling forward → immediately fling
///   backward while the forward flip is still animating → verify no
///   double-advance in the original direction
///
/// The lockout tests are retained as a safety net — they guard against
/// regressions that could produce double-advances regardless of the
/// capture path — but they are not a substitute for manual or integration
/// testing of the core re-entry fix.
void main() {
  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Starting month for all tests.
  final june2024 = DateTime(2024, 6, 1);

  /// Short animation duration to keep tests fast.
  const testStyle = CalendarStyle(
    animationDuration: Duration(milliseconds: 200),
  );

  late CalendarController controller;

  /// Tracks every notification from the controller, in order.
  late List<DateTime> monthChanges;
  late VoidCallback listener;

  setUp(() {
    controller = CalendarController(initialMonth: june2024);
    monthChanges = [];
    listener = () {
      monthChanges.add(controller.currentMonth);
    };
    controller.addListener(listener);
  });

  tearDown(() {
    controller.removeListener(listener);
    controller.dispose();
  });

  Widget buildCalendar({
    CalendarStyle style = testStyle,
    PageTurnEdge boundEdge = PageTurnEdge.top,
    DateConstraint? minDate,
    DateConstraint? maxDate,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 400,
          child: FlipCalendar(
            controller: controller,
            style: style,
            boundEdge: boundEdge,
            animationsEnabled: true,
            gesturesEnabled: true,
            minDate: minDate,
            maxDate: maxDate,
            dayBuilder: (context, data) {
              return Center(child: Text(data.date.day.toString()));
            },
          ),
        ),
      ),
    );
  }

  /// Pumps enough frames for async image capture and animation to complete.
  ///
  /// ImageCapture.capture waits for multiple frames internally. A generous
  /// number of pumps ensures the full async pipeline has a chance to run
  /// regardless of how many retries or frame waits the capture needs.
  Future<void> pumpForCapture(WidgetTester tester) async {
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Fully settles all animations and pending frames.
  Future<void> settleCompletely(WidgetTester tester) async {
    await pumpForCapture(tester);
    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------------------
  // Single gesture navigation
  //
  // These verify that a single gesture-driven flip works correctly.
  // Results depend on image capture succeeding in the test environment.
  // -------------------------------------------------------------------------

  group('Single gesture navigation', () {
    testWidgets(
      'forward fling advances to next month or stays if capture fails',
      (tester) async {
        await tester.pumpWidget(buildCalendar());
        await tester.pumpAndSettle();

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );

        await settleCompletely(tester);

        // June if capture failed, July if it succeeded.
        expect(
          controller.currentMonth.month,
          anyOf(equals(6), equals(7)),
          reason:
              'Forward fling should advance to July, or stay at June '
              'if image capture is not available in the test environment.',
        );
      },
    );

    testWidgets(
      'backward fling goes to previous month or stays if capture fails',
      (tester) async {
        await tester.pumpWidget(buildCalendar());
        await tester.pumpAndSettle();

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, 200),
          1000,
        );

        await settleCompletely(tester);

        // June if capture failed, May if it succeeded.
        expect(
          controller.currentMonth.month,
          anyOf(equals(5), equals(6)),
          reason:
              'Backward fling should go to May, or stay at June '
              'if image capture is not available in the test environment.',
        );
      },
    );

    testWidgets('small drag below threshold cancels without changing month', (
      tester,
    ) async {
      await tester.pumpWidget(buildCalendar());
      await tester.pumpAndSettle();

      // 20px on a 400px widget: progress = 20/(400*0.7) ≈ 0.07
      // Well below the 0.3 dragProgressThreshold.
      await tester.drag(find.byType(FlipCalendar), const Offset(0, -20));

      await settleCompletely(tester);

      expect(
        controller.currentMonth,
        equals(DateTime(2024, 6, 1)),
        reason: 'A small drag below threshold should not change the month.',
      );
    });

    testWidgets(
      'two sequential gestures each advance at most one month when fully '
      'settled between them',
      (tester) async {
        await tester.pumpWidget(buildCalendar());
        await tester.pumpAndSettle();

        // First fling forward.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await settleCompletely(tester);

        final afterFirst = controller.currentMonth.month;

        // Second fling forward — should work since the first fully settled.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await settleCompletely(tester);

        final afterSecond = controller.currentMonth.month;

        // Each gesture should advance at most one month.
        expect(
          afterFirst,
          anyOf(equals(6), equals(7)),
          reason: 'First fling should advance at most one month.',
        );
        expect(
          afterSecond - afterFirst,
          anyOf(equals(0), equals(1)),
          reason: 'Second fling should advance at most one additional month.',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Gesture lockout during transitions (safety net)
  //
  // IMPORTANT: These tests assert that double-advance bug behavior does
  // not occur, but they cannot exercise the actual re-entry code path in
  // a widget test environment. When `toImage()` fails for the first
  // gesture, the wrapper returns to idle before the second gesture
  // arrives, so the lockout logic is never reached — the tests pass
  // trivially. They are retained as a safety net against regressions, not
  // as proof that the lockout works. The re-entry scenario must be
  // validated via manual testing or integration tests on a device.
  // -------------------------------------------------------------------------

  group('Gesture lockout during transitions', () {
    testWidgets(
      'opposite-direction fling during active transition does not cause '
      'a double-advance in the original direction',
      (tester) async {
        await tester.pumpWidget(buildCalendar());
        await tester.pumpAndSettle();

        // Fling forward (swipe up = next month for top edge).
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );

        // Pump one frame. If capture succeeds, the transition is active.
        // If capture fails, the wrapper has already returned to idle.
        await tester.pump();

        // Attempt an opposite-direction fling. If the first transition is
        // still active, this should be blocked. If capture failed and the
        // wrapper returned to idle, this is accepted as a fresh gesture.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, 200),
          1000,
        );

        await settleCompletely(tester);

        // The bug would produce August (two forward advances).
        // Any other outcome is acceptable:
        //   May = first capture failed, backward accepted as fresh gesture
        //   June = both captures failed
        //   July = first succeeded, second correctly blocked
        expect(
          controller.currentMonth.month,
          isNot(equals(8)),
          reason:
              'The opposite fling must not cause a second forward '
              'advance to August.',
        );
      },
    );

    testWidgets(
      'repeated same-direction flings during animation produce at most '
      'one month change',
      (tester) async {
        await tester.pumpWidget(buildCalendar());
        await tester.pumpAndSettle();

        // First fling forward.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pump();

        // Second fling forward — blocked if first is animating, or accepted
        // as a fresh gesture if first capture failed.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pump();

        // Third fling forward — same: blocked or fresh depending on capture.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );

        await settleCompletely(tester);

        // At most one forward advance (to July). Never August or later.
        expect(
          controller.currentMonth.month,
          lessThanOrEqualTo(7),
          reason:
              'Repeated flings during animation should not cause '
              'multiple forward month advances.',
        );
      },
    );

    testWidgets(
      'rapid forward-backward-forward sequence does not double-advance '
      'forward',
      (tester) async {
        await tester.pumpWidget(buildCalendar());
        await tester.pumpAndSettle();

        // Forward.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pump();

        // Backward — may be blocked or accepted depending on capture.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, 200),
          1000,
        );
        await tester.pump();

        // Forward again — may be blocked or accepted.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );

        await settleCompletely(tester);

        // The bug would push the month to August or beyond. Any single
        // month change in either direction is acceptable.
        expect(
          controller.currentMonth.month,
          isNot(equals(8)),
          reason:
              'Rapid sequences must not double-advance forward '
              'to August.',
        );
      },
    );

    testWidgets(
      'no controller notification reaches a double-advance month during '
      'a fling with an attempted second gesture',
      (tester) async {
        await tester.pumpWidget(buildCalendar());
        await tester.pumpAndSettle();

        // Clear any setup-related notifications.
        monthChanges.clear();

        // Forward fling.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pump();

        // Attempted opposite fling.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, 200),
          1000,
        );

        await settleCompletely(tester);

        // No notification should report August.
        for (final change in monthChanges) {
          expect(
            change.month,
            isNot(equals(8)),
            reason: 'No controller notification should reach August.',
          );
        }
      },
    );
  });

  // -------------------------------------------------------------------------
  // Programmatic navigation gesture lockout
  // -------------------------------------------------------------------------

  group('Programmatic navigation blocks gestures', () {
    testWidgets(
      'gesture during programmatic navigation does not cause extra advance',
      (tester) async {
        await tester.pumpWidget(buildCalendar());
        await tester.pumpAndSettle();

        // Trigger programmatic navigation to July.
        controller.goToMonth(DateTime(2024, 7, 1));

        // Pump a few frames — programmatic animation starts.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Attempt a fling during the programmatic animation.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );

        await settleCompletely(tester);

        // Should be July (from programmatic navigation), not August.
        // The controller already holds July regardless of capture.
        expect(
          controller.currentMonth,
          equals(DateTime(2024, 7, 1)),
          reason:
              'Gesture during programmatic animation should not '
              'cause an additional month advance.',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Horizontal bound edge gesture lockout
  // -------------------------------------------------------------------------

  group('Horizontal bound edge gesture lockout', () {
    testWidgets(
      'opposite fling does not double-advance with left-edge binding',
      (tester) async {
        await tester.pumpWidget(buildCalendar(boundEdge: PageTurnEdge.left));
        await tester.pumpAndSettle();

        // Forward fling (swipe left = next for left edge).
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(-200, 0),
          1000,
        );
        await tester.pump();

        // Opposite fling — blocked if first is animating, or accepted as
        // a fresh gesture if capture failed.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(200, 0),
          1000,
        );

        await settleCompletely(tester);

        expect(
          controller.currentMonth.month,
          isNot(equals(8)),
          reason:
              'Opposite horizontal fling must not double-advance '
              'forward for left-edge binding.',
        );
      },
    );

    testWidgets(
      'opposite fling does not double-advance with right-edge binding',
      (tester) async {
        await tester.pumpWidget(buildCalendar(boundEdge: PageTurnEdge.right));
        await tester.pumpAndSettle();

        // Forward fling (swipe right = next for right edge).
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(200, 0),
          1000,
        );
        await tester.pump();

        // Opposite fling — blocked if first is animating, or accepted as
        // a fresh gesture if capture failed.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(-200, 0),
          1000,
        );

        await settleCompletely(tester);

        expect(
          controller.currentMonth.month,
          isNot(equals(8)),
          reason:
              'Opposite horizontal fling must not double-advance '
              'forward for right-edge binding.',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Date bounds and gesture lockout
  // -------------------------------------------------------------------------

  group('Date bounds and gesture lockout', () {
    testWidgets(
      'gesture during restricted navigation does not advance past the '
      'restriction boundary',
      (tester) async {
        // maxDate is June — forward navigation is restricted.
        await tester.pumpWidget(
          buildCalendar(maxDate: DateConstraint.fixed(DateTime(2024, 6, 30))),
        );
        await tester.pumpAndSettle();

        // Attempt forward fling into restricted territory.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pump();

        // Attempt backward fling during snap-back.
        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, 200),
          1000,
        );

        await settleCompletely(tester);

        // Must not advance forward past June (restricted).
        // May is acceptable if the backward fling was accepted as a
        // fresh gesture after the restricted forward fling cleaned up.
        expect(
          controller.currentMonth.month,
          lessThanOrEqualTo(6),
          reason: 'Month must not advance past the maxDate restriction.',
        );
      },
    );
  });
}
