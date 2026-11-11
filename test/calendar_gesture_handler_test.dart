import 'dart:math' as math;

import 'package:flip_calendar/flip_calendar.dart';
import 'package:flip_calendar/src/animation/calendar_gesture_handler.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

/// Pumps a [size] handler bound at [boundEdge], centred in the test view and
/// drawn through [transform] if one is given, and returns the list its
/// reports are added to, in order: `begin next`, `progress 0.250` (the turn,
/// to three places), `complete true`. Each progress report's finger start, to
/// three places, is added to [fingerStarts] if it is given.
Future<List<String>> pumpHandler(
  WidgetTester tester, {
  PageTurnEdge boundEdge = PageTurnEdge.top,
  CalendarStyle style = const CalendarStyle(),
  Size size = const Size(300, 400),
  Widget child = const ColoredBox(color: Colors.blue),
  Matrix4? transform,
  List<String>? fingerStarts,
}) async {
  final reports = <String>[];
  Widget sized = SizedBox.fromSize(
    size: size,
    child: CalendarGestureHandler(
      boundEdge: boundEdge,
      style: style,
      onDragBegin: (direction) => reports.add('begin ${direction.name}'),
      onDragProgress: (turn, fingerStart) {
        reports.add('progress ${turn.toStringAsFixed(3)}');
        fingerStarts?.add(fingerStart.toStringAsFixed(3));
      },
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

/// The progress reports of a next-month drag holding a page [length] px long
/// at its grip, [grip] px from the hinge (at least a tenth of the page), after
/// each of [travels] px of travel toward the hinge: the package's drag
/// progress, each search starting from the last turn, as the handler's does.
List<String> heldReports(
  double length,
  double grip,
  List<double> travels, {
  PageTurnStyle style = const PageTurnStyle(),
}) {
  final drag = PageTurnDragProgress(
    pageLength: length,
    style: style,
    fingerStart: 1 - grip / length,
  );
  var turn = 0.0;
  return [
    for (final travel in travels)
      'progress '
          '${(turn = drag.progressFor(travel, current: turn)).toStringAsFixed(3)}',
  ];
}

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
            onDragProgress: (_, _) {},
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

        // The first 20 px cross the drag threshold: the drag holds the page
        // 180 px from the hinge, and its 180 px of travel are past 0.3 of
        // that way, 54 px.
        await tester.drag(handler, const Offset(0, -200));

        expect(reports.last, 'complete true');
      });

      testWidgets('a drag below the progress threshold does not complete', (
        tester,
      ) async {
        final reports = await pumpHandler(tester);

        // Gripped 180 px from the hinge after the first 20 px, the drag
        // travels 40 px, short of 0.3 of its way, 54 px.
        await tester.drag(handler, const Offset(0, -60));

        expect(reports.last, 'complete false');
      });

      testWidgets('a drag that holds the page completes at exactly the '
          "style's share of its way to the hinge", (tester) async {
        const style = CalendarStyle(dragProgressThreshold: 0.25);

        Future<String> dragOnce(double distance) async {
          final reports = await pumpHandler(tester, style: style);
          final gesture = await tester.startGesture(
            tester.getCenter(handler) + const Offset(0, 20),
          );
          // The first move crosses the drag threshold and is discarded: the
          // grip is 200 px from the hinge, and 0.25 of that is 50 px.
          await gesture.moveBy(const Offset(0, -20));
          await gesture.moveBy(Offset(0, -distance));
          await gesture.up();
          return reports.last;
        }

        expect(await dragOnce(50), 'complete true');
        expect(await dragOnce(49), 'complete false');
      });

      testWidgets('a drag gripped nearer the hinge than the package can hold, '
          "within nearEdgeMaxSpeedUp, completes at the style's share of its "
          'own way to the hinge', (tester) async {
        const style = CalendarStyle(dragProgressThreshold: 0.5);

        Future<String> dragOnce(double distance) async {
          final reports = await pumpHandler(tester, style: style);
          final gesture = await tester.startGesture(
            tester.getTopLeft(handler) + const Offset(150, 45),
          );
          // The grip is 25 px from the hinge, within the tenth of the page
          // the package cannot hold: the paper 40 px from it moves 1.6 times
          // as fast as the finger, within the default 2, so it reaches the
          // hinge with the finger and half its way is 12.5 px of the
          // finger's.
          await gesture.moveBy(const Offset(0, -20));
          await gesture.moveBy(Offset(0, -distance));
          await gesture.up();
          return reports.last;
        }

        expect(await dragOnce(12.5), 'complete true');
        expect(await dragOnce(12), 'complete false');
      });

      testWidgets('a drag gripped nearer the hinge than nearEdgeMaxSpeedUp '
          'allows moves the paper held at most that many times as fast as the '
          "finger, and completes at the style's share of the finger's way to "
          'where that paper reaches the hinge', (tester) async {
        Future<List<String>> dragOnce(
          CalendarStyle style,
          double distance,
        ) async {
          final reports = await pumpHandler(tester, style: style);
          final gesture = await tester.startGesture(
            tester.getTopLeft(handler) + const Offset(150, 30),
          );
          // The grip is 10 px from the hinge: the paper held, 40 px from it,
          // would reach the hinge with the finger at 4 times its speed.
          await gesture.moveBy(const Offset(0, -20));
          await gesture.moveBy(Offset(0, -distance));
          await gesture.up();
          return reports;
        }

        final drag = PageTurnDragProgress(
          pageLength: 400,
          fingerStart: PageTurnInputs.maxFingerStart,
        );
        String progress(double paperTravel) =>
            'progress ${drag.progressFor(paperTravel).toStringAsFixed(3)}';

        // By default at most 2 times: 4 px move the paper 8 px, and half its
        // 40 px way takes 10 px of the finger's.
        const limited = CalendarStyle(dragProgressThreshold: 0.5);
        expect(await dragOnce(limited, 4), [
          'begin next',
          progress(8),
          'complete false',
        ]);
        expect((await dragOnce(limited, 10.25)).last, 'complete true');
        expect((await dragOnce(limited, 9.75)).last, 'complete false');

        // Without a limit, 4 times: half the paper's way takes 5 px.
        const unlimited = CalendarStyle(
          dragProgressThreshold: 0.5,
          nearEdgeMaxSpeedUp: double.infinity,
        );
        expect(await dragOnce(unlimited, 4), [
          'begin next',
          progress(16),
          'complete false',
        ]);
        expect((await dragOnce(unlimited, 5.25)).last, 'complete true');
        expect((await dragOnce(unlimited, 4.75)).last, 'complete false');
      });

      testWidgets(
        "a drag through the box completes at exactly the style's progress "
        'threshold',
        (tester) async {
          // A previous-month drag, through a 200 px drag box: 100 px is
          // progress 0.5.
          const style = CalendarStyle(
            dragBoxFraction: 0.5,
            dragProgressThreshold: 0.5,
          );

          Future<String> dragOnce(double distance) async {
            final reports = await pumpHandler(tester, style: style);
            final gesture = await tester.startGesture(
              tester.getCenter(handler),
            );
            // The first move crosses the drag threshold and is discarded.
            await gesture.moveBy(const Offset(0, 20));
            await gesture.moveBy(Offset(0, distance));
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
        // The second move crosses the touch slop: gripped 170 px from the
        // hinge, the eight after it travel 120 px, past 0.3 of that way.
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
      // Previous-month drags turn through the drag box. The first 20 px of a
      // tester's drag cross the drag threshold and are discarded.

      testWidgets('the drag box follows a change of style', (tester) async {
        // A 280 px drag box (0.7 of 400 px): 40 px is progress 0.14.
        var reports = await pumpHandler(
          tester,
          style: const CalendarStyle(dragBoxFraction: 0.7),
        );
        await tester.drag(handler, const Offset(0, 60));

        expect(reports.last, 'complete false');

        // A 40 px drag box: 40 px turns the page all the way.
        reports = await pumpHandler(
          tester,
          style: const CalendarStyle(dragBoxFraction: 0.1),
        );
        await tester.drag(handler, const Offset(0, 60));

        expect(reports.last, 'complete true');
      });

      testWidgets('the drag box follows a change of bound edge', (
        tester,
      ) async {
        await pumpHandler(tester);
        final reports = await pumpHandler(tester, boundEdge: PageTurnEdge.left);

        // A 210 px drag box (0.7 of 300 px): 70 px is progress 0.33.
        await tester.drag(handler, const Offset(90, 0));

        expect(reports.last, 'complete true');
      });

      testWidgets("the drag box follows the handler's size", (tester) async {
        await pumpHandler(tester);
        final reports = await pumpHandler(tester, size: const Size(300, 200));
        final gesture = await tester.startGesture(tester.getCenter(handler));

        // A 140 px drag box (0.7 of 200 px).
        await gesture.moveBy(const Offset(0, 20));
        await gesture.moveBy(const Offset(0, 70));

        expect(reports, ['begin previous', 'progress 0.500']);
      });
    });

    group('holding the page', () {
      // A next-month drag holds the page where it is gripped: each move
      // reports the package's drag progress for its travel, drawn with the
      // grip's finger start.

      for (final (edge, toHinge) in [
        (PageTurnEdge.top, const Offset(0, -1)),
        (PageTurnEdge.bottom, const Offset(0, 1)),
        (PageTurnEdge.left, const Offset(-1, 0)),
        (PageTurnEdge.right, const Offset(1, 0)),
      ]) {
        testWidgets('a drag toward the ${edge.name} edge holds the page at its '
            'grip', (tester) async {
          final starts = <String>[];
          final reports = await pumpHandler(
            tester,
            boundEdge: edge,
            fingerStarts: starts,
          );
          final length = edge.isVerticalAxis ? 400.0 : 300.0;
          final gesture = await tester.startGesture(tester.getCenter(handler));

          // The first move crosses the drag threshold and is discarded: the
          // grip is 20 px nearer the hinge than the centre.
          await gesture.moveBy(toHinge * 20);
          await gesture.moveBy(toHinge * 50);
          await gesture.moveBy(toHinge * 50);

          final grip = length / 2 - 20;
          expect(reports, [
            'begin next',
            ...heldReports(length, grip, [50, 100]),
          ]);
          expect(starts, everyElement((1 - grip / length).toStringAsFixed(3)));
        });
      }

      testWidgets("a next-month drag ignores the style's dragCurve and drag "
          'box: it holds the page as with the default style', (tester) async {
        final reports = await pumpHandler(
          tester,
          style: const CalendarStyle(
            dragCurve: Curves.decelerate,
            dragBoxFraction: 0.3,
          ),
        );
        final gesture = await tester.startGesture(tester.getCenter(handler));

        // The first move crosses the drag threshold and is discarded: the
        // grip is 180 px from the hinge.
        await gesture.moveBy(const Offset(0, -20));
        await gesture.moveBy(const Offset(0, -50));
        await gesture.moveBy(const Offset(0, -50));

        expect(reports, [
          'begin next',
          ...heldReports(400, 180, [50, 100]),
        ]);
      });

      testWidgets('a drag gripped at or past the hinge turns through the box', (
        tester,
      ) async {
        final starts = <String>[];
        final reports = await pumpHandler(tester, fingerStarts: starts);
        final gesture = await tester.startGesture(
          tester.getTopLeft(handler) + const Offset(150, 10),
        );

        // Accepted 10 px past the hinge, the drag has no paper to hold: its
        // 28 px are 0.1 of the 280 px drag box, drawn from the free edge.
        await gesture.moveBy(const Offset(0, -20));
        await gesture.moveBy(const Offset(0, -28));

        expect(reports, ['begin next', 'progress 0.100']);
        expect(starts, ['0.000']);
      });

      testWidgets('the grip follows the finger back over the flat page, and '
          'the page turns again from there as soon as the finger turns back', (
        tester,
      ) async {
        final starts = <String>[];
        final reports = await pumpHandler(tester, fingerStarts: starts);
        final gesture = await tester.startGesture(tester.getCenter(handler));

        // Gripped 180 px from the hinge, the finger goes 100 px toward it,
        // back to the grip, 100 px past it (the grip following to 280 px),
        // and 150 px toward the hinge again.
        for (final dy in [-20, -50, -50, 50, 50, 50, 50, -50, -50, -50]) {
          await gesture.moveBy(Offset(0, dy.toDouble()));
        }

        expect(reports, [
          'begin next',
          ...heldReports(400, 180, [50, 100, 50]),
          'progress 0.000',
          'progress 0.000',
          'progress 0.000',
          ...heldReports(400, 280, [50, 100, 150]),
        ]);
        expect(starts, [
          ...List.filled(4, '0.550'),
          '0.425',
          ...List.filled(4, '0.300'),
        ]);
      });

      testWidgets('past the end of the turn the page stays turned until the '
          'finger is back where the turn ends', (tester) async {
        final reports = await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));

        // Gripped 180 px from the hinge, the turn ends between 500 and 700 px
        // of travel: 700 and 800 px leave it turned, and so does the way back
        // to 700 px; at 500 px it is the turn for 500 px.
        for (final dy in [-20, -700, -100, 100, 200]) {
          await gesture.moveBy(Offset(0, dy.toDouble()));
        }

        expect(reports, [
          'begin next',
          ...heldReports(400, 180, [700, 800, 700, 500]),
        ]);
        expect(reports.sublist(1, 4), everyElement('progress 1.000'));
        expect(reports.last, isNot('progress 1.000'));
      });

      testWidgets('the hold follows a change of style, keeping its grip and '
          'travel', (tester) async {
        // Five strips: a page this coarse is seen, and so held, differently.
        const coarse = PageTurnStyle(segments: 5);
        await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));
        // Gripped 180 px from the hinge, 50 px with the default style, then
        // 50 px more with the coarse one.
        await gesture.moveBy(const Offset(0, -20));
        await gesture.moveBy(const Offset(0, -50));

        final reports = await pumpHandler(
          tester,
          style: const CalendarStyle(pageTurnStyle: coarse),
        );
        await gesture.moveBy(const Offset(0, -50));

        final before = PageTurnDragProgress(pageLength: 400, fingerStart: 0.55);
        final after = PageTurnDragProgress(
          pageLength: 400,
          style: coarse,
          fingerStart: 0.55,
        );
        final turn = after.progressFor(100, current: before.progressFor(50));
        expect(reports, ['progress ${turn.toStringAsFixed(3)}']);
      });

      testWidgets("the hold follows the handler's size, keeping its grip and "
          'travel as shares of the page', (tester) async {
        await pumpHandler(tester);
        final gesture = await tester.startGesture(
          tester.getCenter(handler) + const Offset(0, 20),
        );
        // Gripped at 0.5 of the 400 px page, 50 px of travel is 0.125 of it.
        await gesture.moveBy(const Offset(0, -20));
        await gesture.moveBy(const Offset(0, -50));

        // On a 512 px page that is 64 px; 64 px more make 128 px.
        final reports = await pumpHandler(tester, size: const Size(300, 512));
        await gesture.moveBy(const Offset(0, -64));

        final before = PageTurnDragProgress(pageLength: 400, fingerStart: 0.5);
        final after = PageTurnDragProgress(pageLength: 512, fingerStart: 0.5);
        final turn = after.progressFor(128, current: before.progressFor(50));
        expect(reports, ['progress ${turn.toStringAsFixed(3)}']);
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

      // A next-month drag from the centre of the 400 px handler, gripped where
      // it crosses the touch slop, reports the package's drag progress for
      // its travel from there (see heldReports); a previous-month drag turns
      // through the 280 px drag box, each 50 px being 0.179.

      testWidgets('the move that crosses the threshold is discarded, and the '
          'next is the first progress', (tester) async {
        final reports = await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));

        await gesture.moveBy(const Offset(0, -20));
        await gesture.moveBy(const Offset(0, -100));
        await gesture.up();

        expect(reports, [
          'begin next',
          ...heldReports(400, 180, [100]),
          'complete true',
        ]);
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
          ...heldReports(400, 180, [for (var i = 1; i <= 10; i++) 10.0 * i]),
          'complete true',
        ]);
      });

      testWidgets('progress through the box falls back to 0 past the start, '
          'and rises again as soon as the finger turns back', (tester) async {
        final reports = await pumpHandler(tester);
        final gesture = await tester.startGesture(tester.getCenter(handler));

        // The first move crosses the drag threshold and is discarded.
        for (final dy in [20, 50, 50, -50, -50, -50, 50, 50, 50]) {
          await gesture.moveBy(Offset(0, dy.toDouble()));
        }
        await gesture.up();

        expect(reports, [
          'begin previous',
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
        for (final dy in [20, 100, 100, 100, 50, -50, -50]) {
          await gesture.moveBy(Offset(0, dy.toDouble()));
        }

        expect(reports, [
          'begin previous',
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
        // the threshold and is discarded: the grip is 150 px from the hinge.
        await gesture.moveBy(const Offset(0, -25));
        await gesture.moveBy(const Offset(0, -25));
        await gesture.moveBy(const Offset(0, -25));

        expect(reports, [
          'begin next',
          ...heldReports(400, 150, [50, 100]),
        ]);
      });

      testWidgets("progress is measured in the handler's own coordinates, "
          'under a rotated ancestor', (tester) async {
        final reports = await pumpHandler(
          tester,
          transform: Matrix4.rotationZ(math.pi),
        );
        final gesture = await tester.startGesture(tester.getCenter(handler));

        // Down on screen is up in the handler. The first move crosses the
        // threshold and is discarded: the grip is 150 px from the hinge.
        await gesture.moveBy(const Offset(0, 50));
        await gesture.moveBy(const Offset(0, 50));
        await gesture.moveBy(const Offset(0, 50));

        expect(reports, [
          'begin next',
          ...heldReports(400, 150, [50, 100]),
        ]);
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

          expect(reports, [
            'begin next',
            ...heldReports(400, 180, [50, 100]),
          ]);
        },
      );

      testWidgets('a next-month drag accepted past the free edge lies flat '
          'until the finger is back over the page', (tester) async {
        final reports = await pumpHandler(tester);
        final bottom = tester.getBottomLeft(handler).dy;
        final gesture = await tester.startGesture(Offset(400, bottom - 5));

        // The first move crosses the drag threshold and is discarded: the
        // drag is accepted 15 px below the free edge. The next 10 px leave the
        // finger 5 px below it, and 10 px more bring it 5 px onto the page.
        await gesture.moveBy(const Offset(0, 20));
        await gesture.moveBy(const Offset(0, -10));
        await gesture.moveBy(const Offset(0, -10));

        expect(reports, hasLength(3));
        expect(reports.take(2), ['begin next', 'progress 0.000']);
        expect(reports.last, isNot('progress 0.000'));
      });
    });

    group('flicks', () {
      // A 60 px drag from the centre of the 400 px handler stops short of 0.3
      // of its way to the hinge wherever Flutter accepts it: the touch slop s
      // shortens the travel and the way alike, and 60 - s px stays short of
      // 0.3 x (200 - s) px. It completes only as a flick.

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
        // On the 600 px handler too, 60 px from the centre stop short of 0.3
        // of the way to the hinge.
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
        // 150 px up over 1.5 s, accepted on the second move: 130 px from a
        // grip 180 px from the hinge, past 0.3 of that way.
        for (var i = 1; i <= 15; i++) {
          await gesture.moveBy(
            const Offset(0, -10),
            timeStamp: Duration(milliseconds: 100 * i),
          );
        }
        // Then 30 px down in 20 ms, which leaves 100 px, still past it: the
        // flick against the drag decides.
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
