import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for swipes on FlipCalendar: a drag below the threshold, and
/// a swipe during a programmatic navigation.
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

  late ValueNotifier<DateTime> clock;
  late CalendarController controller;
  late List<CalendarHapticType> haptics;

  setUp(() {
    clock = ValueNotifier(DateTime(2024, 6, 12));
    controller = CalendarController(initialMonth: june2024, clock: clock);
    haptics = [];
  });

  tearDown(() {
    // A test that fails with an exception pending leaves its calendar mounted
    // until the next test resets the tree, and it leaves the controller then:
    // the controller must still work.
    if (find.byType(FlipCalendar).evaluate().isNotEmpty) return;
    controller.dispose();
    clock.dispose();
  });

  Widget buildCalendar() {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 400,
          child: FlipCalendar(
            controller: controller,
            style: testStyle,
            onHapticFeedback: haptics.add,
            dayBuilder: (context, data) {
              return Center(child: Text(data.date.day.toString()));
            },
          ),
        ),
      ),
    );
  }

  group('Single gesture navigation', () {
    testWidgets('small drag below threshold cancels without changing month', (
      tester,
    ) async {
      await tester.pumpWidget(buildCalendar());
      await tester.pumpAndSettle();

      // 60 px of the 280 px drag box (0.7 of 400 px): progress 0.21, below
      // the 0.3 dragProgressThreshold.
      await tester.drag(find.byType(FlipCalendar), const Offset(0, -60));

      await tester.pumpAndSettle();

      expect(
        controller.currentMonth,
        equals(june2024),
        reason: 'A small drag below threshold should not change the month.',
      );
      expect(controller.isNavigating, isFalse);
    });
  });

  group('Programmatic navigation blocks gestures', () {
    testWidgets(
      'a fling during a programmatic page turn leaves the destination '
      'unchanged',
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

        await tester.pumpAndSettle();

        // Should be July (from programmatic navigation), not August.
        expect(
          controller.currentMonth,
          equals(DateTime(2024, 7, 1)),
          reason: 'A fling during a programmatic page turn is ignored.',
        );
        // The calendar ignores the fling: it starts no swipe, so it sends no
        // haptic either (a swipe started while busy would be restricted).
        expect(haptics, isEmpty);
      },
    );
  });
}
