import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlipCalendar widget', () {
    late CalendarController controller;

    setUp(() {
      controller = CalendarController(initialMonth: DateTime(2024, 6, 1));
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildCalendar({
      CalendarStyle style = const CalendarStyle(),
      DateTime? selectedDate,
      void Function(DateTime)? onDayTap,
      int firstDayOfWeek = DateTime.sunday,
      DateConstraint? maxDate,
      DateConstraint? minDate,
      bool animationsEnabled = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: FlipCalendar(
            controller: controller,
            selectedDate: selectedDate,
            onDayTap: onDayTap,
            style: style,
            firstDayOfWeek: firstDayOfWeek,
            maxDate: maxDate,
            minDate: minDate,
            animationsEnabled: animationsEnabled,
            dayBuilder: (context, data) {
              return Center(
                child: Text(
                  data.date.day.toString(),
                  key: data.isCurrentMonth ? Key('day-${data.date.day}') : null,
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('renders calendar grid with day numbers', (tester) async {
      await tester.pumpWidget(buildCalendar());

      // Day 15 is unique to June — not in adjacent month bleed
      expect(find.text('15'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('30'), findsWidgets);
    });

    testWidgets('renders weekday header', (tester) async {
      await tester.pumpWidget(buildCalendar());

      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
    });

    testWidgets('uses custom weekday names', (tester) async {
      await tester.pumpWidget(
        buildCalendar(
          style: const CalendarStyle(
            weekdayNames: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'],
          ),
        ),
      );

      expect(find.text('Su'), findsOneWidget);
      expect(find.text('Mo'), findsOneWidget);
    });

    testWidgets('calls onDayTap when day is tapped', (tester) async {
      DateTime? tapped;

      await tester.pumpWidget(buildCalendar(onDayTap: (date) => tapped = date));

      await tester.tap(find.byKey(const Key('day-15')));
      await tester.pump();

      expect(tapped, isNotNull);
      expect(tapped!.day, equals(15));
    });

    testWidgets('passes correct isSelected to dayBuilder', (tester) async {
      bool? wasSelected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlipCalendar(
              controller: controller,
              selectedDate: DateTime(2024, 6, 15),
              animationsEnabled: false,
              dayBuilder: (context, data) {
                if (data.date.day == 15 && data.isCurrentMonth) {
                  wasSelected = data.isSelected;
                }
                return Center(child: Text(data.date.day.toString()));
              },
            ),
          ),
        ),
      );

      expect(wasSelected, isTrue);
    });

    testWidgets('passes correct isToday to dayBuilder', (tester) async {
      final todayController = CalendarController(initialMonth: DateTime.now());
      bool? foundToday;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlipCalendar(
              controller: todayController,
              animationsEnabled: false,
              dayBuilder: (context, data) {
                if (data.isToday) foundToday = true;
                return Center(child: Text(data.date.day.toString()));
              },
            ),
          ),
        ),
      );

      expect(foundToday, isTrue);
      todayController.dispose();
    });

    testWidgets('disables dates outside maxDate bound', (tester) async {
      final todayController = CalendarController(initialMonth: DateTime.now());
      bool? futureEnabled;
      final now = DateTime.now();
      final tomorrowDay = now.day + 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlipCalendar(
              controller: todayController,
              maxDate: DateConstraint.today(),
              animationsEnabled: false,
              dayBuilder: (context, data) {
                if (data.date.day == tomorrowDay && data.isCurrentMonth) {
                  futureEnabled = data.isEnabled;
                }
                return Center(child: Text(data.date.day.toString()));
              },
            ),
          ),
        ),
      );

      // Only check if not near end of month
      if (tomorrowDay <= 28) {
        expect(futureEnabled, isFalse);
      }

      todayController.dispose();
    });

    testWidgets('updates when controller changes month', (tester) async {
      await tester.pumpWidget(buildCalendar());

      // June — day 15 visible
      expect(find.text('15'), findsOneWidget);

      // Switch to July
      controller.goToMonth(DateTime(2024, 7, 1));
      await tester.pump();

      // July has 31 days
      expect(find.text('31'), findsWidgets);
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('applies custom style without error', (tester) async {
      await tester.pumpWidget(
        buildCalendar(style: const CalendarStyle(weekdayHeaderHeight: 60.0)),
      );

      expect(find.byType(FlipCalendar), findsOneWidget);
    });
  });

  group('CalendarDayData', () {
    test('equality works correctly', () {
      final a = CalendarDayData(
        date: DateTime(2024, 6, 15),
        isCurrentMonth: true,
        isToday: false,
        isSelected: false,
        isFutureDate: false,
        isEnabled: true,
        row: 2,
        column: 6,
      );
      final b = CalendarDayData(
        date: DateTime(2024, 6, 15),
        isCurrentMonth: true,
        isToday: false,
        isSelected: false,
        isFutureDate: false,
        isEnabled: true,
        row: 2,
        column: 6,
      );
      expect(a, equals(b));
    });

    test('inequality when properties differ', () {
      final a = CalendarDayData(
        date: DateTime(2024, 6, 15),
        isCurrentMonth: true,
        isToday: false,
        isSelected: false,
        isFutureDate: false,
        isEnabled: true,
        row: 2,
        column: 6,
      );
      final b = CalendarDayData(
        date: DateTime(2024, 6, 16),
        isCurrentMonth: true,
        isToday: false,
        isSelected: false,
        isFutureDate: false,
        isEnabled: true,
        row: 2,
        column: 6,
      );
      expect(a, isNot(equals(b)));
    });

    test('toString is readable', () {
      final data = CalendarDayData(
        date: DateTime(2024, 6, 15),
        isCurrentMonth: true,
        isToday: true,
        isSelected: false,
        isFutureDate: false,
        isEnabled: true,
        row: 2,
        column: 6,
      );
      expect(data.toString(), contains('CalendarDayData'));
      expect(data.toString(), contains('isToday: true'));
    });
  });

  group('CalendarStyle', () {
    test('default constructor creates valid style', () {
      const style = CalendarStyle();
      expect(style.calendarBackground, equals(const Color(0xFFFFFFFF)));
      expect(style.gridLineWidth, equals(1.0));
      expect(style.weekdayHeaderHeight, equals(40.0));
      expect(style.weekdayNames.length, equals(7));
    });

    test('dark factory has different colors', () {
      final dark = CalendarStyle.dark();
      expect(
        dark.weekdayHeaderBackground,
        isNot(equals(const Color(0xFFF5F5F5))),
      );
      expect(dark.calendarBackground, equals(const Color(0xFF212121)));
    });

    test('copyWith preserves unspecified values', () {
      const original = CalendarStyle(gridLineWidth: 3.0);
      final modified = original.copyWith(dayTextSize: 20.0);

      expect(modified.gridLineWidth, equals(3.0));
      expect(modified.dayTextSize, equals(20.0));
      expect(modified.calendarBackground, equals(const Color(0xFFFFFFFF)));
    });

    test('copyWith updates calendarBackground', () {
      const original = CalendarStyle();
      final modified = original.copyWith(
        calendarBackground: const Color(0xFF000000),
      );

      expect(modified.calendarBackground, equals(const Color(0xFF000000)));
      expect(modified.gridLineWidth, equals(1.0));
    });

    test('equality works', () {
      const a = CalendarStyle();
      const b = CalendarStyle();
      expect(a, equals(b));
    });

    test('inequality when calendarBackground differs', () {
      const a = CalendarStyle();
      const b = CalendarStyle(calendarBackground: Color(0xFF000000));
      expect(a, isNot(equals(b)));
    });
  });

  group('MultiMonthAnimationMode', () {
    test('has expected values', () {
      expect(MultiMonthAnimationMode.values.length, equals(2));
      expect(
        MultiMonthAnimationMode.values,
        contains(MultiMonthAnimationMode.sequential),
      );
      expect(
        MultiMonthAnimationMode.values,
        contains(MultiMonthAnimationMode.directJump),
      );
    });
  });
}
