import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

void main() {
  final month = DateTime(2024, 6);

  Widget host({
    required CalendarController controller,
    required double height,
    required CalendarStyle style,
    required Widget Function(BuildContext, CalendarDayData) dayBuilder,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: height,
            child: FlipCalendar(
              controller: controller,
              style: style,
              dayBuilder: dayBuilder,
            ),
          ),
        ),
      ),
    );
  }

  CalendarController controllerFor(WidgetTester tester, {bool animated = false}) {
    final controller = CalendarController(
      initialMonth: month,
      animationsEnabled: animated,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
    return controller;
  }

  Finder header(CalendarStyle style) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color ==
              style.weekdayHeaderBackground,
    );
  }

  for (final height in [0.0, 10.0, 40.0, 400.0]) {
    testWidgets('the default header fits a $height pixel viewport', (
      tester,
    ) async {
      final controller = controllerFor(tester);
      const style = CalendarStyle();
      final built = <DateTime>{};
      await tester.pumpWidget(
        host(
          controller: controller,
          height: height,
          style: style,
          dayBuilder: (context, data) {
            built.add(data.date);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(tester.takeException(), isNull);
      expect(header(style), findsOneWidget);
      expect(tester.getSize(header(style)).height, height < 40 ? height : 40);
      expect(
        built.length,
        MonthGrid.forMonth(month, firstDayOfWeek: DateTime.sunday).totalCells,
      );
    });
  }

  testWidgets('the header uses the height remaining inside padding', (
    tester,
  ) async {
    final controller = controllerFor(tester);
    const style = CalendarStyle(padding: EdgeInsets.all(20));
    await tester.pumpWidget(
      host(
        controller: controller,
        height: 50,
        style: style,
        dayBuilder: (context, data) => const SizedBox.shrink(),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(header(style)).height, 10);
  });

  testWidgets('a zero-height default calendar settles and keeps building cells', (
    tester,
  ) async {
    final controller = controllerFor(tester, animated: true);
    final built = <DateTime>{};
    Widget page(double height) => host(
      controller: controller,
      height: height,
      style: const CalendarStyle(),
      dayBuilder: (context, data) {
        built.add(data.date);
        return const SizedBox.shrink();
      },
    );
    await tester.pumpWidget(page(0));
    built.clear();
    controller.nextMonth();
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(controller.currentMonth, DateTime(2024, 7));
    expect(controller.isNavigating, isFalse);
    expect(find.byType(PageTurnAnimation), findsNothing);
    expect(built.any((date) => date.year == 2024 && date.month == 7), isTrue);
    await tester.pumpWidget(page(400));
    expect(tester.takeException(), isNull);
    expect(controller.currentMonth, DateTime(2024, 7));
  });

  for (final scenario in [
    (month: DateTime(-271821, 5), delta: 15.0),
    (month: DateTime(275760, 8), delta: -15.0),
  ]) {
    testWidgets(
      'a swipe past ${scenario.month.year}-${scenario.month.month} '
      'stays restricted',
      (tester) async {
        final controller = CalendarController(initialMonth: scenario.month);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
        });
        final haptics = <CalendarHapticType>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 400,
                  child: FlipCalendar(
                    controller: controller,
                    onHapticFeedback: haptics.add,
                    dayBuilder: (context, data) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        for (var step = 0; step < 10; step++) {
          await gesture.moveBy(Offset(0, scenario.delta));
        }
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(controller.currentMonth, scenario.month);
        expect(controller.isNavigating, isFalse);
        expect(haptics, [CalendarHapticType.navigationRestricted]);
      },
    );
  }
}
