import 'package:flip_calendar/flip_calendar.dart';
import 'package:flip_calendar/src/animation/calendar_gesture_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

void main() {
  group('CalendarGestureHandler', () {
    group('DragDirection enum', () {
      test('has next and previous values', () {
        expect(DragDirection.values.length, equals(2));
        expect(DragDirection.values, contains(DragDirection.next));
        expect(DragDirection.values, contains(DragDirection.previous));
      });
    });

    group('renders child', () {
      testWidgets('shows child widget', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CalendarGestureHandler(
                boundEdge: PageTurnEdge.top,
                isAnimating: false,
                style: const CalendarStyle(),
                onDragBegin: (_) {},
                onDragProgress: (_) {},
                onDragComplete: (_) {},
                child: const Text('Test Child'),
              ),
            ),
          ),
        );

        expect(find.text('Test Child'), findsOneWidget);
      });

      testWidgets('wraps child in GestureDetector', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CalendarGestureHandler(
                boundEdge: PageTurnEdge.top,
                isAnimating: false,
                style: const CalendarStyle(),
                onDragBegin: (_) {},
                onDragProgress: (_) {},
                onDragComplete: (_) {},
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        );

        expect(find.byType(GestureDetector), findsOneWidget);
      });
    });

    group('vertical gestures (top/bottom edge)', () {
      testWidgets('detects vertical drag with top edge', (tester) async {
        DragDirection? detected;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: CalendarGestureHandler(
                  boundEdge: PageTurnEdge.top,
                  isAnimating: false,
                  style: const CalendarStyle(),
                  onDragBegin: (dir) => detected = dir,
                  onDragProgress: (_) {},
                  onDragComplete: (_) {},
                  child: Container(color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        await tester.drag(find.byType(GestureDetector), const Offset(0, -100));
        await tester.pump();

        expect(detected, isNotNull);
      });

      testWidgets('detects vertical drag with bottom edge', (tester) async {
        DragDirection? detected;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: CalendarGestureHandler(
                  boundEdge: PageTurnEdge.bottom,
                  isAnimating: false,
                  style: const CalendarStyle(),
                  onDragBegin: (dir) => detected = dir,
                  onDragProgress: (_) {},
                  onDragComplete: (_) {},
                  child: Container(color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        await tester.drag(find.byType(GestureDetector), const Offset(0, 100));
        await tester.pump();

        expect(detected, isNotNull);
      });
    });

    group('horizontal gestures (left/right edge)', () {
      testWidgets('detects horizontal drag with left edge', (tester) async {
        DragDirection? detected;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: CalendarGestureHandler(
                  boundEdge: PageTurnEdge.left,
                  isAnimating: false,
                  style: const CalendarStyle(),
                  onDragBegin: (dir) => detected = dir,
                  onDragProgress: (_) {},
                  onDragComplete: (_) {},
                  child: Container(color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        await tester.drag(find.byType(GestureDetector), const Offset(-100, 0));
        await tester.pump();

        expect(detected, isNotNull);
      });

      testWidgets('detects horizontal drag with right edge', (tester) async {
        DragDirection? detected;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: CalendarGestureHandler(
                  boundEdge: PageTurnEdge.right,
                  isAnimating: false,
                  style: const CalendarStyle(),
                  onDragBegin: (dir) => detected = dir,
                  onDragProgress: (_) {},
                  onDragComplete: (_) {},
                  child: Container(color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        await tester.drag(find.byType(GestureDetector), const Offset(100, 0));
        await tester.pump();

        expect(detected, isNotNull);
      });
    });

    group('animation state', () {
      testWidgets('ignores gestures when animating', (tester) async {
        DragDirection? detected;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: CalendarGestureHandler(
                  boundEdge: PageTurnEdge.top,
                  isAnimating: true,
                  style: const CalendarStyle(),
                  onDragBegin: (dir) => detected = dir,
                  onDragProgress: (_) {},
                  onDragComplete: (_) {},
                  child: Container(color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        await tester.drag(find.byType(GestureDetector), const Offset(0, -100));
        await tester.pump();

        expect(detected, isNull);
      });
    });

    group('maxProgressAllowed', () {
      testWidgets('clamps progress to max', (tester) async {
        double? lastProgress;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: CalendarGestureHandler(
                  boundEdge: PageTurnEdge.top,
                  isAnimating: false,
                  maxProgressAllowed: 0.5,
                  style: const CalendarStyle(),
                  onDragBegin: (_) {},
                  onDragProgress: (p) => lastProgress = p,
                  onDragComplete: (_) {},
                  child: Container(color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        await tester.drag(find.byType(GestureDetector), const Offset(0, -300));
        await tester.pump();

        if (lastProgress != null) {
          expect(lastProgress, lessThanOrEqualTo(0.5));
        }
      });
    });

    group('drag completion', () {
      testWidgets('completes when drag exceeds progress threshold', (
        tester,
      ) async {
        bool? completionResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: CalendarGestureHandler(
                  boundEdge: PageTurnEdge.top,
                  isAnimating: false,
                  style: const CalendarStyle(),
                  onDragBegin: (_) {},
                  onDragProgress: (_) {},
                  onDragComplete: (result) => completionResult = result,
                  child: Container(color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        // 400 * 0.7 = 280px drag box; 0.3 threshold → need ≥84px
        // Dragging 200px up gives progress ≈ 0.71
        await tester.drag(find.byType(GestureDetector), const Offset(0, -200));
        await tester.pump();

        expect(completionResult, isTrue);
      });

      testWidgets('cancels when drag is below progress threshold', (
        tester,
      ) async {
        bool? completionResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: CalendarGestureHandler(
                  boundEdge: PageTurnEdge.top,
                  isAnimating: false,
                  style: const CalendarStyle(),
                  onDragBegin: (_) {},
                  onDragProgress: (_) {},
                  onDragComplete: (result) => completionResult = result,
                  child: Container(color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        // 20px drag gives progress ≈ 0.07, well below 0.3 threshold
        await tester.drag(find.byType(GestureDetector), const Offset(0, -20));
        await tester.pump();

        expect(completionResult, isFalse);
      });
    });
  });
}
