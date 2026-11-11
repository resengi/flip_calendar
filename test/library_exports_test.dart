import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The page_turn_animation types the API takes come with flip_calendar's own
/// import: this file imports nothing from page_turn_animation.
void main() {
  testWidgets('flip_calendar alone gives the bound edge and page-turn style '
      'its API takes', (tester) async {
    final clock = ValueNotifier(DateTime(2024, 6, 12));
    final controller = CalendarController(clock: clock);
    addTearDown(() {
      controller.dispose();
      clock.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 400,
          child: FlipCalendar(
            controller: controller,
            boundEdge: PageTurnEdge.left,
            style: const CalendarStyle(
              pageTurnStyle: PageTurnStyle(curlIntensity: 2),
            ),
            dayBuilder: (_, data) => Text('${data.date.day}'),
          ),
        ),
      ),
    );

    final calendar = tester.widget<FlipCalendar>(find.byType(FlipCalendar));
    expect(calendar.boundEdge, PageTurnEdge.left);
    expect(calendar.style.pageTurnStyle.curlIntensity, 2);
  });
}
