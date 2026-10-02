import 'dart:math' as math;

import 'package:flip_calendar/flip_calendar.dart';
import 'package:flip_calendar/src/animation/calendar_gesture_handler.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

/// Pumps a [size] handler bound at [boundEdge], centred in the test view and
/// drawn through [transform] if one is given, and returns the list its
/// reports are added to, in order: `begin next`, `progress 0.250` (to three
/// places), `complete true`.
Future<List<String>> pumpHandler(
  WidgetTester tester, {
  PageTurnEdge boundEdge = PageTurnEdge.top,
  CalendarStyle style = const CalendarStyle(),
  Size size = const Size(300, 400),
  Widget child = const ColoredBox(color: Colors.blue),
  Matrix4? transform,
}) async {
  final reports = <String>[];
  Widget sized = SizedBox.fromSize(
    size: size,
    child: CalendarGestureHandler(
      boundEdge: boundEdge,
      style: style,
      onDragBegin: (direction) => reports.add('begin ${direction.name}'),
      onDragProgress: (progress) =>
          reports.add('progress ${progress.toStringAsFixed(3)}'),
      onDragComplete: (completes) => reports.add('complete $completes'),
      child: child,
    ),
  );
  if (transform != null) {
    sized = Transform(
      transform: transform,
      alignment: Alignment.center,
      child: sized,
    );
  }
  await tester.pumpWidget(Center(child: sized));
  return reports;
}

final handler = find.byType(CalendarGestureHandler);

void main() {
  group('CalendarGestureHandler', () {
    testWidgets('a handler accepts a new drag after being re-enabled', (
      tester,
    ) async {
      var enabled = true;
      final begins = <DragDirection>[];

      Widget subject() => Center(
        child: SizedBox(
          width: 300,
          height: 400,
          child: CalendarGestureHandler(
            enabled: enabled,
            boundEdge: PageTurnEdge.top,
            style: const CalendarStyle(),
            onDragBegin: begins.add,
            onDragProgress: (_) {},
            onDragComplete: (_) {},
            child: const ColoredBox(color: Colors.blue),
          ),
        ),
      );

      await tester.pumpWidget(subject());
      final first = await tester.startGesture(tester.getCenter(handler));
      // The first move crosses the drag threshold and is discarded.
      await first.moveBy(const Offset(0, -20));
      await first.moveBy(const Offset(0, -40));
      expect(begins, [DragDirection.next]);

      enabled = false;
      await tester.pumpWidget(subject());
      enabled = true;
      await tester.pumpWidget(subject());
      await first.up();

      await tester.drag(handler, const Offset(0, -100));
      expect(begins, [DragDirection.next, DragDirection.next]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    group('renders child', () {
      testWidgets('shows its child', (tester) async {
        await pumpHandler(
          tester,
          child: const Text('Test Child', textDirection: TextDirection.ltr),
        );

        expect(find.text('Test Child'), findsOneWidget);
      });
    });

    group('vertical gestures (top/bottom edge)', () {
      testWidgets('a drag toward the top edge is next', (tester) async {
        final reports = await pumpHandler(tester);

        await tester.drag(handler, const Offset(0, -100));

        expect(reports.first, 'begin next');
      });

      testWidgets('a drag toward the bottom edge is next', (tester) async {
        final reports = await pumpHandler(
          tester,
          boundEdge: PageTurnEdge.bottom,
        );

        await tester.drag(handler, const Offset(0, 100));

        expect(reports.first, 'begin next');
      });

      testWidgets('a drag away from the top or bottom edge is previous', (
        tester,
      ) async {
        var reports = await pumpHandler(tester);
        await tester.drag(handler, const Offset(0, 100));
        expect(reports.first, 'begin previous');

        reports = await pumpHandler(tester, boundEdge: PageTurnEdge.bottom);
        await tester.drag(handler, const Offset(0, -100));
        expect(reports.first, 'begin previous');
      });
    });

    group('horizontal gestures (left/right edge)', () {
      testWidgets('a drag toward the left edge is next', (tester) async {
        final reports = await pumpHandler(tester, boundEdge: PageTurnEdge.left);

        await tester.drag(handler, const Offset(-100, 0));

        expect(reports.first, 'begin next');
      });

      testWidgets('a drag toward the right edge is next', (tester) async {
        final reports = await pumpHandler(
          tester,
          boundEdge: PageTurnEdge.right,
        );

        await tester.drag(handler, const Offset(100, 0));

        expect(reports.first, 'begin next');
      });

      testWidgets('a drag away from the left or right edge is previous', (
        tester,
      ) async {
        var reports = await pumpHandler(tester, boundEdge: PageTurnEdge.left);
        await tester.drag(handler, const Offset(100, 0));
        expect(reports.first, 'begin previous');

        reports = await pumpHandler(tester, boundEdge: PageTurnEdge.right);
        await tester.drag(handler, const Offset(-100, 0));
        expect(reports.first, 'begin previous');
      });
    });

    group('drag completion', () {
      testWidgets('a drag past the progress threshold completes', (
        tester,
      ) async {
        final reports = await pumpHandler(tester);

        // 400 * 0.7 = 280px drag box; 0.3 threshold → need ≥84px
        // Dragging 200px up gives progress ≈ 0.71
        await tester.drag(handler, const Offset(0, -200));

        expect(reports.last, 'complete true');
      });

      testWidgets('a drag below the progress threshold does not complete', (
        tester,
      ) async {
        final reports = await pumpHandler(tester);

        // 400 * 0.7 = 280px drag box; 60px gives progress ≈ 0.21, below the
        // 0.3 threshold
        await tester.drag(handler, const Offset(0, -60));

        expect(reports.last, 'complete false');
      });

      testWidgets(
        "a drag completes at exactly the style's progress threshold",
        (tester) async {
          // A 200 px drag box: 100 px is progress 0.5.
          const style = CalendarStyle(
            dragBoxSizePercentage: 0.5,
            dragProgressThreshold: 0.5,
          );

          Future<String> dragOnce(double distance) async {
            final reports = await pumpHandler(tester, style: style);
            final gesture = await tester.startGesture(
              tester.getCenter(handler),
            );
            // The first move crosses the drag threshold and is discarded.
            await gesture.moveBy(const Offset(0, -20));
            await gesture.moveBy(Offset(0, -distance));
            await gesture.up();
            return reports.last;
          }

          expect(await dragOnce(100), 'complete true');
          expect(await dragOnce(99), 'complete false');
        },
      );

      testWidgets('a cancelled pointer ends the drag without completing', (
        tester,
      ) async {
        final reports = await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));
        // 150 px: progress 0.536, past the threshold.
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, -15));
        }

        await gesture.cancel();

        expect(reports.where((report) => report.startsWith('complete')), [
          'complete false',
        ]);
      });

      testWidgets('a pointer cancelled before it moves reports nothing', (
        tester,
      ) async {
        final reports = await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));

        await gesture.cancel();

        expect(reports, isEmpty);
      });

      testWidgets('a collapse to no size ends the drag after that frame, and '
          'the rest of the drag is ignored', (tester) async {
        final reports = await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));
        await gesture.moveBy(const Offset(0, -15));
        await gesture.moveBy(const Offset(0, -15));
        await gesture.moveBy(const Offset(0, -15));
        expect(reports.first, 'begin next');

        final collapsed = await pumpHandler(tester, size: const Size(300, 0));
        expect(collapsed, ['complete false']);

        final restored = await pumpHandler(tester);
        await gesture.moveBy(const Offset(0, -100));
        await gesture.up();
        expect(collapsed, ['complete false']);
        expect(restored, isEmpty);

        await tester.drag(handler, const Offset(0, -100));
        expect(restored.first, 'begin next');
      });

      testWidgets('a pointer that is down when the handler collapses is '
          'ignored, though its drag begins after', (tester) async {
        final child = GestureDetector(
          onTap: () {},
          child: const ColoredBox(color: Colors.blue),
        );
        await pumpHandler(tester, child: child);
        // The tap recognizer keeps the drag from being accepted until the
        // pointer has moved past the touch slop.
        final gesture = await tester.startGesture(tester.getCenter(handler));

        final collapsed = await pumpHandler(
          tester,
          size: const Size(300, 0),
          child: child,
        );
        final restored = await pumpHandler(tester, child: child);
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, -10));
        }
        await gesture.up();

        expect(collapsed, isEmpty);
        expect(restored, isEmpty);
      });

      testWidgets('a change of bound edge along the axis drops the drag '
          'without an end', (tester) async {
        final reports = await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));
        await gesture.moveBy(const Offset(0, -15));
        await gesture.moveBy(const Offset(0, -15));
        await gesture.moveBy(const Offset(0, -15));
        expect(reports.first, 'begin next');

        final changed = await pumpHandler(
          tester,
          boundEdge: PageTurnEdge.bottom,
        );
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 15));
        }
        await gesture.up();

        expect(changed, isEmpty);
      });

      testWidgets('a change of bound edge to the other axis drops the drag '
          'without an end', (tester) async {
        final reports = await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));
        await gesture.moveBy(const Offset(0, -15));
        await gesture.moveBy(const Offset(0, -15));
        await gesture.moveBy(const Offset(0, -15));
        expect(reports.first, 'begin next');

        final changed = await pumpHandler(tester, boundEdge: PageTurnEdge.left);
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(-15, 0));
        }
        await gesture.up();

        expect(changed, isEmpty);
      });

      testWidgets('a tap reports nothing', (tester) async {
        final reports = await pumpHandler(tester);

        await tester.tap(handler);

        expect(reports, isEmpty);
      });

      testWidgets('a move only across the axis reports nothing', (
        tester,
      ) async {
        final reports = await pumpHandler(tester);

        await tester.drag(handler, const Offset(100, 0));

        expect(reports, isEmpty);
      });
    });

    group('thresholds', () {
      testWidgets('the drag box follows a change of style', (tester) async {
        // 400 * 0.7 = 280px drag box; 60px gives progress ≈ 0.21
        var reports = await pumpHandler(
          tester,
          style: const CalendarStyle(dragBoxSizePercentage: 0.7),
        );
        await tester.drag(handler, const Offset(0, -60));

        expect(reports.last, 'complete false');

        // 400 * 0.1 = 40px drag box; 60px gives full progress
        reports = await pumpHandler(
          tester,
          style: const CalendarStyle(dragBoxSizePercentage: 0.1),
        );
        await tester.drag(handler, const Offset(0, -60));

        expect(reports.last, 'complete true');
      });

      testWidgets('the drag box follows a change of bound edge', (
        tester,
      ) async {
        await pumpHandler(tester);
        final reports = await pumpHandler(tester, boundEdge: PageTurnEdge.left);

        // 300 * 0.7 = 210px drag box; 70px after the 20px that cross the
        // threshold gives progress ≈ 0.33
        await tester.drag(handler, const Offset(-90, 0));

        expect(reports.last, 'complete true');
      });

      testWidgets("the drag box follows the handler's size", (tester) async {
        await pumpHandler(tester);
        final reports = await pumpHandler(tester, size: const Size(300, 200));
        final gesture = await tester.startGesture(tester.getCenter(handler));

        // The first move crosses the drag threshold and is discarded.
        await gesture.moveBy(const Offset(0, -20));
        // 200 * 0.7 = 140 px drag box.
        await gesture.moveBy(const Offset(0, -70));

        expect(reports, ['begin next', 'progress 0.500']);
      });
    });

    group('movement along the axis', () {
      testWidgets('a fling begins in its own direction and completes', (
        tester,
      ) async {
        final reports = await pumpHandler(tester);

        // The fling's first move has no distance.
        await tester.fling(handler, const Offset(0, -200), 2000);

        expect(reports.first, 'begin next');
        expect(reports.last, 'complete true');
      });

      // The 400 px handler's drag box is 280 px: each 50 px is 0.179.

      testWidgets('the move that crosses the threshold is discarded, and the '
          'next is the first progress', (tester) async {
        final reports = await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));

        await gesture.moveBy(const Offset(0, -20));
        await gesture.moveBy(const Offset(0, -100));
        await gesture.up();

        expect(reports, ['begin next', 'progress 0.357', 'complete true']);
      });

      testWidgets('progress counts from the point of acceptance, with a '
          'tappable child', (tester) async {
        final reports = await pumpHandler(
          tester,
          child: GestureDetector(
            onTap: () {},
            child: const ColoredBox(color: Colors.blue),
          ),
        );
        final gesture = await tester.startGesture(tester.getCenter(handler));

        // The drag is accepted on the second move, past the touch slop, and
        // Flutter discards that move: the ten after it are progress.
        for (var i = 0; i < 12; i++) {
          await gesture.moveBy(const Offset(0, -10));
        }
        await gesture.up();

        expect(reports, [
          'begin next',
          'progress 0.036',
          'progress 0.071',
          'progress 0.107',
          'progress 0.143',
          'progress 0.179',
          'progress 0.214',
          'progress 0.250',
          'progress 0.286',
          'progress 0.321',
          'progress 0.357',
          'complete true',
        ]);
      });

      testWidgets('progress falls back to 0 past the start, and rises again '
          'as soon as the finger turns back', (tester) async {
        final reports = await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));

        // The first move crosses the drag threshold and is discarded.
        for (final dy in [-20, -50, -50, 50, 50, 50, -50, -50, -50]) {
          await gesture.moveBy(Offset(0, dy.toDouble()));
        }
        await gesture.up();

        expect(reports, [
          'begin next',
          'progress 0.179',
          'progress 0.357',
          'progress 0.179',
          'progress 0.000',
          'progress 0.000',
          'progress 0.179',
          'progress 0.357',
          'progress 0.536',
          'complete true',
        ]);
      });

      testWidgets('progress stops at 1 past the drag box, and falls again as '
          'soon as the finger turns back', (tester) async {
        final reports = await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));

        // The first move crosses the drag threshold and is discarded.
        for (final dy in [-20, -100, -100, -100, -50, 50, 50]) {
          await gesture.moveBy(Offset(0, dy.toDouble()));
        }

        expect(reports, [
          'begin next',
          'progress 0.357',
          'progress 0.714',
          'progress 1.000',
          'progress 1.000',
          'progress 0.821',
          'progress 0.643',
        ]);
      });

      testWidgets("progress is measured in the handler's own coordinates, "
          'under a scaled ancestor', (tester) async {
        final reports = await pumpHandler(
          tester,
          transform: Matrix4.diagonal3Values(0.5, 0.5, 1),
        );
        final gesture = await tester.startGesture(tester.getCenter(handler));

        // 25 px on screen is 50 px in the handler. The first move crosses
        // the threshold and is discarded.
        await gesture.moveBy(const Offset(0, -25));
        await gesture.moveBy(const Offset(0, -25));
        await gesture.moveBy(const Offset(0, -25));

        expect(reports, ['begin next', 'progress 0.179', 'progress 0.357']);
      });

      testWidgets("progress is measured in the handler's own coordinates, "
          'under a rotated ancestor', (tester) async {
        final reports = await pumpHandler(
          tester,
          transform: Matrix4.rotationZ(math.pi),
        );
        final gesture = await tester.startGesture(tester.getCenter(handler));

        // Down on screen is up in the handler. The first move crosses the
        // threshold and is discarded.
        await gesture.moveBy(const Offset(0, 50));
        await gesture.moveBy(const Offset(0, 50));
        await gesture.moveBy(const Offset(0, 50));

        expect(reports, ['begin next', 'progress 0.179', 'progress 0.357']);
      });

      testWidgets(
        'a later move with no motion along the axis reports nothing',
        (tester) async {
          final reports = await pumpHandler(tester);
          final gesture = await tester.startGesture(tester.getCenter(handler));

          // The first move crosses the drag threshold and is discarded.
          await gesture.moveBy(const Offset(0, -20));
          await gesture.moveBy(const Offset(0, -50));
          await gesture.moveBy(const Offset(30, 0));
          await gesture.moveBy(const Offset(0, -50));

          expect(reports, ['begin next', 'progress 0.179', 'progress 0.357']);
        },
      );
    });

    group('flicks', () {
      // A 60 px drag on the 400 px handler is progress 0.214, below the 0.3
      // threshold: it completes only as a flick.

      testWidgets(
        "a release faster than the style's speed is a flick, and slower is not",
        (tester) async {
          // 0.25 × 400 px per 200 ms: 500 px/s.
          const style = CalendarStyle(
            flickDistanceThreshold: 0.25,
            flickMaxDuration: Duration(milliseconds: 200),
          );
          var reports = await pumpHandler(tester, style: style);
          await tester.fling(handler, const Offset(0, -60), 550);
          expect(reports.last, 'complete true');

          reports = await pumpHandler(tester, style: style);
          await tester.fling(handler, const Offset(0, -60), 450);
          expect(reports.last, 'complete false');
        },
      );

      testWidgets("the style's speed follows the handler's size", (
        tester,
      ) async {
        // 0.25 × 400 px per 200 ms is 500 px/s; at 600 px it is 750 px/s.
        const style = CalendarStyle(
          flickDistanceThreshold: 0.25,
          flickMaxDuration: Duration(milliseconds: 200),
        );
        var reports = await pumpHandler(tester, style: style);
        await tester.fling(handler, const Offset(0, -60), 600);
        expect(reports.last, 'complete true');

        reports = await pumpHandler(
          tester,
          style: style,
          size: const Size(300, 600),
        );
        await tester.fling(handler, const Offset(0, -60), 600);
        // 60 px on the 600 px handler is progress 0.143.
        expect(reports.last, 'complete false');
      });

      testWidgets(
        'a flick counts with a flickMaxDuration under a millisecond',
        (tester) async {
          // 0.001 × 400 px per 500 µs: 800 px/s.
          final reports = await pumpHandler(
            tester,
            style: const CalendarStyle(
              flickDistanceThreshold: 0.001,
              flickMaxDuration: Duration(microseconds: 500),
            ),
          );

          await tester.fling(handler, const Offset(0, -60), 2000);

          expect(reports.last, 'complete true');
        },
      );

      testWidgets(
        "a flick counts above 8000 px/s, Flutter's default fling limit",
        (tester) async {
          // 0.05 × 400 px per 1 ms: 20000 px/s.
          final reports = await pumpHandler(
            tester,
            style: const CalendarStyle(
              flickMaxDuration: Duration(milliseconds: 1),
            ),
          );

          await tester.fling(handler, const Offset(0, -60), 30000);

          expect(reports.last, 'complete true');
        },
      );

      testWidgets(
        'a fast release is a flick only after moving more than the touch '
        'slop just before it',
        (tester) async {
          Future<List<String>> dragThenRelease(double lastMoves) async {
            final reports = await pumpHandler(tester);
            final gesture = await tester.startGesture(
              tester.getCenter(handler),
            );
            // 60 px up over 600 ms, then a pause.
            for (var i = 1; i <= 6; i++) {
              await gesture.moveBy(
                const Offset(0, -10),
                timeStamp: Duration(milliseconds: 100 * i),
              );
            }
            // Then [lastMoves] moves of 3 px, 2 ms apart: 1500 px/s. After
            // the pause, Flutter measures the fling from the first of them
            // to the last.
            for (var i = 1; i <= lastMoves; i++) {
              await gesture.moveBy(
                const Offset(0, -3),
                timeStamp: Duration(milliseconds: 700 + 2 * i),
              );
            }
            await gesture.up();
            return reports;
          }

          // 6 px, under the 18 px touch slop.
          expect((await dragThenRelease(3)).last, 'complete false');
          // 27 px.
          expect((await dragThenRelease(10)).last, 'complete true');
        },
      );

      testWidgets("a flick against the drag's direction does not complete", (
        tester,
      ) async {
        final reports = await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));
        // 150 px up over 1.5 s: progress 0.536.
        for (var i = 1; i <= 15; i++) {
          await gesture.moveBy(
            const Offset(0, -10),
            timeStamp: Duration(milliseconds: 100 * i),
          );
        }
        // Then 30 px down in 20 ms, which leaves progress 0.429.
        for (var i = 1; i <= 10; i++) {
          await gesture.moveBy(
            const Offset(0, 3),
            timeStamp: Duration(milliseconds: 1500 + 2 * i),
          );
        }
        await gesture.up();

        expect(reports.last, 'complete false');
      });
    });

    group('pointers', () {
      testWidgets('a second finger is ignored until the first lifts', (
        tester,
      ) async {
        final reports = await pumpHandler(tester);
        final center = tester.getCenter(handler);

        final first = await tester.startGesture(center);
        for (var i = 0; i < 3; i++) {
          await first.moveBy(const Offset(0, -10));
        }
        final reportsBeforeSecond = reports.length;

        final second = await tester.startGesture(center + const Offset(0, 150));
        await second.moveBy(const Offset(0, -1));
        await second.moveBy(const Offset(0, -100));
        expect(reports, hasLength(reportsBeforeSecond));

        await first.moveBy(const Offset(0, -10));
        expect(reports, hasLength(reportsBeforeSecond + 1));
        expect(reports.last, startsWith('progress'));

        await second.up();
        expect(reports, hasLength(reportsBeforeSecond + 1));
        await first.up();
        expect(reports.last, 'complete false');

        final reportsBeforeThird = reports.length;
        await tester.drag(handler, const Offset(0, -100));
        expect(reports[reportsBeforeThird], 'begin next');
      });

      testWidgets('a trackpad pan is ignored while a finger drags', (
        tester,
      ) async {
        final reports = await pumpHandler(tester);
        final center = tester.getCenter(handler);

        final finger = await tester.startGesture(center);
        for (var i = 0; i < 3; i++) {
          await finger.moveBy(const Offset(0, -10));
        }
        final reportsBeforePan = reports.length;

        final pan = await tester.startGesture(
          center + const Offset(0, 150),
          kind: PointerDeviceKind.trackpad,
        );
        await pan.moveBy(const Offset(0, -100));
        await pan.up();
        expect(reports, hasLength(reportsBeforePan));

        await finger.up();
        expect(reports.last, 'complete false');
      });

      testWidgets('a finger is ignored while a trackpad pans', (tester) async {
        final reports = await pumpHandler(tester);
        final center = tester.getCenter(handler);

        final pan = await tester.startGesture(
          center,
          kind: PointerDeviceKind.trackpad,
        );
        for (var i = 0; i < 3; i++) {
          await pan.moveBy(const Offset(0, -10));
        }
        expect(reports.first, 'begin next');
        final reportsBeforeFinger = reports.length;

        final finger = await tester.startGesture(center + const Offset(0, 150));
        await finger.moveBy(const Offset(0, -100));
        await finger.up();
        expect(reports, hasLength(reportsBeforeFinger));

        await pan.up();
        expect(reports.last, 'complete false');
      });
    });
  });
}
