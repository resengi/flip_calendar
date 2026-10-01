import 'dart:ui' as ui;

import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

import 'error_matchers.dart';

void main() {
  group('FlipCalendar widget', () {
    late ValueNotifier<DateTime> clock;
    late List<CalendarController> controllers;
    late CalendarController controller;

    CalendarController createController({
      DateTime? initialMonth,
      DateConstraint? minDate,
      DateConstraint? maxDate,
      bool animationsEnabled = false,
    }) {
      final created = CalendarController(
        initialMonth: initialMonth ?? DateTime(2024, 6, 1),
        clock: clock,
        minDate: minDate,
        maxDate: maxDate,
        animationsEnabled: animationsEnabled,
      );
      controllers.add(created);
      return created;
    }

    setUp(() {
      clock = ValueNotifier(DateTime(2024, 6, 12));
      controllers = [];
      controller = createController();
    });

    tearDown(() {
      // A test that fails with an exception pending leaves its calendars
      // mounted until the next test resets the tree, and they leave their
      // controllers then: those controllers must still work.
      if (find.byType(FlipCalendar).evaluate().isNotEmpty) return;
      for (final created in controllers) {
        created.dispose();
      }
      clock.dispose();
    });

    Widget dayCell(BuildContext context, CalendarDayData data) {
      return Center(
        child: Text(
          data.date.day.toString(),
          key: data.isCurrentMonth
              ? Key('${data.date.month}-${data.date.day}')
              : null,
        ),
      );
    }

    FlipCalendar calendar({
      CalendarController? calendarController,
      CalendarStyle style = const CalendarStyle(),
      DateTime? selectedDate,
      void Function(DateTime)? onDayTap,
      void Function(CalendarHapticType)? onHapticFeedback,
      int firstDayOfWeek = DateTime.sunday,
      PageTurnEdge boundEdge = PageTurnEdge.top,
      bool gesturesEnabled = true,
      Widget Function(BuildContext, CalendarDayData)? dayBuilder,
    }) {
      return FlipCalendar(
        controller: calendarController ?? controller,
        dayBuilder: dayBuilder ?? dayCell,
        selectedDate: selectedDate,
        onDayTap: onDayTap,
        onHapticFeedback: onHapticFeedback,
        style: style,
        firstDayOfWeek: firstDayOfWeek,
        boundEdge: boundEdge,
        gesturesEnabled: gesturesEnabled,
      );
    }

    Widget app(Widget child) {
      return MaterialApp(home: Scaffold(body: child));
    }

    /// The weekday names the header shows, left to right.
    List<String?> headerNames(WidgetTester tester) {
      return tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  CalendarStyle.defaultWeekdayNames.contains(widget.data),
            ),
          )
          .map((text) => text.data)
          .toList();
    }

    Widget page(Widget child) {
      return SizedBox(width: 300, height: 400, child: child);
    }

    testWidgets("the grid shows June's first and last day", (tester) async {
      await tester.pumpWidget(app(page(calendar())));

      expect(find.byKey(const Key('6-1')), findsOneWidget);
      expect(find.byKey(const Key('6-30')), findsOneWidget);
    });

    testWidgets('the header names start from each first day of the week', (
      tester,
    ) async {
      const namesFrom = {
        DateTime.monday: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        DateTime.tuesday: ['Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Mon'],
        DateTime.wednesday: ['Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue'],
        DateTime.thursday: ['Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed'],
        DateTime.friday: ['Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu'],
        DateTime.saturday: ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        DateTime.sunday: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      };

      for (final MapEntry(key: firstDay, value: names) in namesFrom.entries) {
        await tester.pumpWidget(app(page(calendar(firstDayOfWeek: firstDay))));

        expect(headerNames(tester), equals(names), reason: 'day $firstDay');
      }
    });

    testWidgets('uses custom weekday names', (tester) async {
      await tester.pumpWidget(
        app(
          page(
            calendar(
              style: const CalendarStyle(
                weekdayNames: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Su'), findsOneWidget);
      expect(find.text('Mo'), findsOneWidget);
    });

    testWidgets('calls onDayTap when day is tapped', (tester) async {
      DateTime? tapped;

      await tester.pumpWidget(
        app(page(calendar(onDayTap: (date) => tapped = date))),
      );

      await tester.tap(find.byKey(const Key('6-15')));

      expect(tapped, equals(DateTime(2024, 6, 15)));
    });

    testWidgets('a tap on a disabled day does not call onDayTap', (
      tester,
    ) async {
      DateTime? tapped;

      await tester.pumpWidget(
        app(
          page(
            calendar(
              calendarController: createController(
                maxDate: DateConstraint.today(),
              ),
              onDayTap: (date) => tapped = date,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('6-20')));

      expect(tapped, isNull);
    });

    testWidgets("a tap on another month's day calls onDayTap with its date", (
      tester,
    ) async {
      DateTime? tapped;

      await tester.pumpWidget(
        app(page(calendar(onDayTap: (date) => tapped = date))),
      );

      // June's page starts on May 26; June has no 31st.
      await tester.tap(find.text('31'));

      expect(tapped, equals(DateTime(2024, 5, 31)));
    });

    testWidgets('marks only the selected date isSelected', (tester) async {
      final selected = <DateTime>{};

      await tester.pumpWidget(
        app(
          page(
            calendar(
              selectedDate: DateTime(2024, 6, 15),
              dayBuilder: (context, data) {
                if (data.isSelected) selected.add(data.date);
                return Center(child: Text(data.date.day.toString()));
              },
            ),
          ),
        ),
      );

      expect(selected, equals({DateTime(2024, 6, 15)}));
    });

    testWidgets('marks only the clock\'s day isToday', (tester) async {
      final todays = <DateTime>{};

      await tester.pumpWidget(
        app(
          page(
            calendar(
              dayBuilder: (context, data) {
                if (data.isToday) todays.add(data.date);
                return Center(child: Text(data.date.day.toString()));
              },
            ),
          ),
        ),
      );

      expect(todays, equals({DateTime(2024, 6, 12)}));
    });

    testWidgets("marks only the days after the clock's day isFutureDate", (
      tester,
    ) async {
      final shown = <DateTime>{};
      final future = <DateTime>{};

      await tester.pumpWidget(
        app(
          page(
            calendar(
              dayBuilder: (context, data) {
                shown.add(data.date);
                if (data.isFutureDate) future.add(data.date);
                return Center(child: Text(data.date.day.toString()));
              },
            ),
          ),
        ),
      );

      // The page shows May 26 to July 6; the clock's day is June 12.
      expect(future, hasLength(24));
      expect(
        future,
        equals(
          shown.where((date) => date.isAfter(DateTime(2024, 6, 12))).toSet(),
        ),
      );
    });

    testWidgets('gives each day its row and column on the page', (
      tester,
    ) async {
      final places = <DateTime, (int, int)>{};

      await tester.pumpWidget(
        app(
          page(
            calendar(
              dayBuilder: (context, data) {
                places[data.date] = (data.row, data.column);
                return Center(child: Text(data.date.day.toString()));
              },
            ),
          ),
        ),
      );

      // Sunday first: the page's six rows run from May 26 to July 6.
      expect(places[DateTime(2024, 5, 26)], equals((0, 0)));
      expect(places[DateTime(2024, 6, 1)], equals((0, 6)));
      expect(places[DateTime(2024, 6, 2)], equals((1, 0)));
      expect(places[DateTime(2024, 6, 12)], equals((2, 3)));
      expect(places[DateTime(2024, 7, 6)], equals((5, 6)));
    });

    testWidgets('disables dates outside maxDate bound', (tester) async {
      final isEnabledByDay = <int, bool>{};

      await tester.pumpWidget(
        app(
          page(
            calendar(
              calendarController: createController(
                maxDate: DateConstraint.today(),
              ),
              dayBuilder: (context, data) {
                if (data.isCurrentMonth) {
                  isEnabledByDay[data.date.day] = data.isEnabled;
                }
                return Center(child: Text(data.date.day.toString()));
              },
            ),
          ),
        ),
      );

      expect(isEnabledByDay[13], isFalse);
      expect(isEnabledByDay[12], isTrue);
    });

    testWidgets('disables dates before the minDate bound', (tester) async {
      final isEnabledByDay = <int, bool>{};

      await tester.pumpWidget(
        app(
          page(
            calendar(
              calendarController: createController(
                minDate: DateConstraint.fixed(DateTime(2024, 6, 10)),
              ),
              dayBuilder: (context, data) {
                if (data.isCurrentMonth) {
                  isEnabledByDay[data.date.day] = data.isEnabled;
                }
                return Center(child: Text(data.date.day.toString()));
              },
            ),
          ),
        ),
      );

      expect(isEnabledByDay[9], isFalse);
      expect(isEnabledByDay[10], isTrue);
    });

    testWidgets('updates when controller changes month', (tester) async {
      await tester.pumpWidget(app(page(calendar())));

      expect(find.byKey(const Key('6-15')), findsOneWidget);

      controller.goToMonth(DateTime(2024, 7, 1));
      await tester.pump();

      expect(find.byKey(const Key('7-31')), findsOneWidget);
      expect(controller.isNavigating, isFalse);
    });

    testWidgets('applies weekdayHeaderHeight to the header', (tester) async {
      await tester.pumpWidget(
        app(
          page(calendar(style: const CalendarStyle(weekdayHeaderHeight: 60))),
        ),
      );

      // The names are centred in the header, at the top of the page.
      expect(
        tester.getCenter(find.text('Sun')).dy -
            tester.getTopLeft(find.byType(FlipCalendar)).dy,
        equals(30),
      );
    });

    group('cell layout', () {
      /// The tap target of the day cell of June [day].
      Finder cell(int day) {
        return find
            .ancestor(
              of: find.byKey(Key('6-$day')),
              matching: find.byType(GestureDetector),
            )
            .first;
      }

      testWidgets('every day cell has the same size', (tester) async {
        await tester.pumpWidget(app(page(calendar())));

        // June 4 is inside the grid, June 8 in the last column, June 30 in
        // the last row.
        final size = tester.getSize(cell(4));
        expect(tester.getSize(cell(8)), equals(size));
        expect(tester.getSize(cell(30)), equals(size));
      });

      testWidgets("the header's names line up with the day columns", (
        tester,
      ) async {
        await tester.pumpWidget(app(page(calendar())));

        // June 2024 starts on a Saturday: June 2 is a Sunday, June 8 a
        // Saturday.
        expect(
          tester.getCenter(find.text('Sun')).dx,
          equals(tester.getCenter(cell(2)).dx),
        );
        expect(
          tester.getCenter(find.text('Sat')).dx,
          equals(tester.getCenter(cell(8)).dx),
        );
      });
    });

    group('cell styling', () {
      /// The box decorations above the content of June [day]'s cell.
      List<BoxDecoration> decorationsAbove(WidgetTester tester, int day) {
        return tester
            .widgetList<DecoratedBox>(
              find.ancestor(
                of: find.byKey(Key('6-$day')),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .toList();
      }

      testWidgets(
        'outlines only today and colours only the disabled and selected days',
        (tester) async {
          const style = CalendarStyle();
          final todayOutline = Border.all(
            color: style.todayBorderColor,
            width: style.todayBorderWidth,
          );

          await tester.pumpWidget(
            app(
              page(
                calendar(
                  calendarController: createController(
                    maxDate: DateConstraint.today(),
                  ),
                  selectedDate: DateTime(2024, 6, 10),
                ),
              ),
            ),
          );

          // Today is June 12, days after it are disabled, June 10 is
          // selected.
          for (var day = 1; day <= 30; day++) {
            final decorations = decorationsAbove(tester, day);
            expect(
              decorations.map((decoration) => decoration.border),
              day == 12
                  ? contains(todayOutline)
                  : isNot(contains(todayOutline)),
              reason: 'June $day',
            );
            expect(
              decorations.map((decoration) => decoration.color),
              day > 12
                  ? contains(style.disabledDateBackground)
                  : isNot(contains(style.disabledDateBackground)),
              reason: 'June $day',
            );
            expect(
              decorations.map((decoration) => decoration.color),
              day == 10
                  ? contains(style.selectedDayBackground)
                  : isNot(contains(style.selectedDayBackground)),
              reason: 'June $day',
            );
          }
        },
      );

      testWidgets('a selected day that is disabled has the disabled colour', (
        tester,
      ) async {
        const style = CalendarStyle();

        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: createController(
                  maxDate: DateConstraint.today(),
                ),
                selectedDate: DateTime(2024, 6, 20),
              ),
            ),
          ),
        );

        final colors = decorationsAbove(
          tester,
          20,
        ).map((decoration) => decoration.color);
        expect(colors, contains(style.disabledDateBackground));
        expect(colors, isNot(contains(style.selectedDayBackground)));
      });

      testWidgets("only today's cell has todayMargin around its content", (
        tester,
      ) async {
        await tester.pumpWidget(
          app(
            page(
              calendar(
                style: const CalendarStyle(
                  todayMargin: EdgeInsets.all(5),
                  todayBorderWidth: 0,
                  gridLineWidth: 0,
                ),
                dayBuilder: (context, data) =>
                    SizedBox.expand(key: ValueKey(data.date)),
              ),
            ),
          ),
        );

        Rect content(int day) {
          return tester.getRect(find.byKey(ValueKey(DateTime(2024, 6, day))));
        }

        Rect cell(int day) {
          return tester.getRect(
            find
                .ancestor(
                  of: find.byKey(ValueKey(DateTime(2024, 6, day))),
                  matching: find.byType(GestureDetector),
                )
                .first,
          );
        }

        // Today is June 12.
        expect(content(12), rectMoreOrLessEquals(cell(12).deflate(5)));
        expect(content(13), rectMoreOrLessEquals(cell(13)));
      });

      testWidgets("only today's cell has todayBorderRadius", (tester) async {
        const radius = BorderRadius.all(Radius.circular(7));

        await tester.pumpWidget(
          app(
            page(
              calendar(style: const CalendarStyle(todayBorderRadius: radius)),
            ),
          ),
        );

        // Today is June 12.
        expect(
          decorationsAbove(
            tester,
            12,
          ).map((decoration) => decoration.borderRadius),
          contains(radius),
        );
        expect(
          decorationsAbove(
            tester,
            13,
          ).map((decoration) => decoration.borderRadius),
          isNot(contains(radius)),
        );
      });

      /// Matches a render object that paints something in [color].
      ///
      /// A Paint holds its colour at lower precision than a Color, so the
      /// colours are compared as 32-bit values.
      PaintPattern paintsIn(Color color) {
        return paints..something(
          (method, arguments) => arguments.any(
            (argument) =>
                argument is Paint &&
                argument.color.toARGB32() == color.toARGB32(),
          ),
        );
      }

      // Flutter draws a side of width 0 as a hairline, so these widths must
      // draw no side at all.
      const lineColor = Color(0xFFFF0000);

      testWidgets('a grid line width of 0 draws no grid or header line', (
        tester,
      ) async {
        await tester.pumpWidget(
          app(
            page(
              calendar(style: const CalendarStyle(gridLineColor: lineColor)),
            ),
          ),
        );
        expect(
          tester.renderObject(find.byType(FlipCalendar)),
          paintsIn(lineColor),
        );

        await tester.pumpWidget(
          app(
            page(
              calendar(
                style: const CalendarStyle(
                  gridLineColor: lineColor,
                  gridLineWidth: 0,
                ),
              ),
            ),
          ),
        );
        expect(
          tester.renderObject(find.byType(FlipCalendar)),
          isNot(paintsIn(lineColor)),
        );
      });

      testWidgets('a today border width of 0 draws no outline', (tester) async {
        await tester.pumpWidget(
          app(
            page(
              calendar(style: const CalendarStyle(todayBorderColor: lineColor)),
            ),
          ),
        );
        expect(
          tester.renderObject(find.byType(FlipCalendar)),
          paintsIn(lineColor),
        );

        await tester.pumpWidget(
          app(
            page(
              calendar(
                style: const CalendarStyle(
                  todayBorderColor: lineColor,
                  todayBorderWidth: 0,
                ),
              ),
            ),
          ),
        );
        expect(
          tester.renderObject(find.byType(FlipCalendar)),
          isNot(paintsIn(lineColor)),
        );
      });
    });

    group('page style', () {
      const pageRect = Rect.fromLTWH(0, 0, 300, 400);

      testWidgets('calendarBackground fills the page', (tester) async {
        const background = Color(0xFF123456);

        await tester.pumpWidget(
          app(
            page(
              calendar(
                style: const CalendarStyle(calendarBackground: background),
              ),
            ),
          ),
        );

        expect(
          tester.renderObject(find.byType(FlipCalendar)),
          paints..rect(rect: pageRect, color: background),
        );
      });

      testWidgets('borderRadius clips the page', (tester) async {
        const radius = BorderRadius.all(Radius.circular(12));

        await tester.pumpWidget(
          app(page(calendar(style: const CalendarStyle(borderRadius: radius)))),
        );

        expect(
          tester.renderObject(find.byType(FlipCalendar)),
          paints..clipRRect(rrect: radius.toRRect(pageRect)),
        );
      });

      testWidgets('padding insets the header and the day cells', (
        tester,
      ) async {
        await tester.pumpWidget(
          app(
            page(
              calendar(
                style: const CalendarStyle(
                  padding: EdgeInsets.fromLTRB(10, 20, 30, 40),
                  gridLineWidth: 0,
                ),
                dayBuilder: (context, data) =>
                    SizedBox.expand(key: ValueKey(data.date)),
              ),
            ),
          ),
        );

        // With no grid lines, the cells fill the padded page below the 40 px
        // header: May 26 is the first cell, July 6 the last.
        expect(
          tester.getTopLeft(find.byKey(ValueKey(DateTime(2024, 5, 26)))),
          offsetMoreOrLessEquals(const Offset(10, 20 + 40)),
        );
        expect(
          tester.getBottomRight(find.byKey(ValueKey(DateTime(2024, 7, 6)))),
          offsetMoreOrLessEquals(const Offset(300 - 30, 400 - 40)),
        );
      });

      testWidgets('weekdayHeaderBackground fills the header', (tester) async {
        const background = Color(0xFF654321);

        await tester.pumpWidget(
          app(
            page(
              calendar(
                style: const CalendarStyle(
                  weekdayHeaderBackground: background,
                  gridLineWidth: 0,
                ),
              ),
            ),
          ),
        );

        // With no lines, the header's background is the page's top 40 px.
        // A Paint holds its colour at lower precision than a Color, so the
        // colours are compared as 32-bit values.
        expect(
          tester.renderObject(find.byType(FlipCalendar)),
          paints..something(
            (method, arguments) =>
                method == #drawRect &&
                arguments[0] == const Rect.fromLTWH(0, 0, 300, 40) &&
                (arguments[1] as Paint).color.toARGB32() ==
                    background.toARGB32(),
          ),
        );
      });

      testWidgets('weekdayTextStyle styles the weekday names', (tester) async {
        const textStyle = TextStyle(fontSize: 11, color: Color(0xFF00FF00));

        await tester.pumpWidget(
          app(
            page(
              calendar(style: const CalendarStyle(weekdayTextStyle: textStyle)),
            ),
          ),
        );

        final shown = tester
            .renderObject<RenderParagraph>(find.text('Sun'))
            .text
            .style!;
        expect(shown.fontSize, equals(11));
        expect(shown.color, equals(const Color(0xFF00FF00)));
      });

      testWidgets(
        'without weekdayTextStyle, the names are in weekdayHeaderTextColor',
        (tester) async {
          const textColor = Color(0xFF00FF00);

          await tester.pumpWidget(
            app(
              page(
                calendar(
                  style: const CalendarStyle(weekdayHeaderTextColor: textColor),
                ),
              ),
            ),
          );

          expect(
            tester
                .renderObject<RenderParagraph>(find.text('Sun'))
                .text
                .style!
                .color,
            equals(textColor),
          );
        },
      );
    });

    group('first day of week', () {
      testWidgets('Monday first rotates the header and starts on a Monday', (
        tester,
      ) async {
        DateTime? firstCell;

        await tester.pumpWidget(
          app(
            page(
              calendar(
                firstDayOfWeek: DateTime.monday,
                dayBuilder: (context, data) {
                  if (data.row == 0 && data.column == 0) firstCell = data.date;
                  return Center(child: Text(data.date.day.toString()));
                },
              ),
            ),
          ),
        );

        expect(
          headerNames(tester),
          equals(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']),
        );
        expect(firstCell, equals(DateTime(2024, 5, 27)));
      });
    });

    group('swipes with animations off', () {
      testWidgets('a fling up turns to the next month', (tester) async {
        await tester.pumpWidget(app(page(calendar())));

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(find.byKey(const Key('7-1')), findsOneWidget);
      });

      testWidgets('a fling down turns to the previous month', (tester) async {
        await tester.pumpWidget(app(page(calendar())));

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, 200),
          1000,
        );
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 5, 1)));
        expect(find.byKey(const Key('5-1')), findsOneWidget);
      });

      testWidgets('a drag below the threshold stays on the month', (
        tester,
      ) async {
        await tester.pumpWidget(app(page(calendar())));

        // 60 px of the 280 px drag box: progress 0.21, below 0.3.
        await tester.drag(find.byType(FlipCalendar), const Offset(0, -60));
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
      });

      testWidgets('a fling toward a forbidden month stays and signals once', (
        tester,
      ) async {
        final haptics = <CalendarHapticType>[];
        final bounded = createController(
          maxDate: DateConstraint.fixed(DateTime(2024, 6, 30)),
        );

        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: bounded,
                onHapticFeedback: haptics.add,
              ),
            ),
          ),
        );

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pumpAndSettle();

        expect(bounded.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(haptics, equals([CalendarHapticType.navigationRestricted]));
      });

      testWidgets('a request made from the haptic callback is ignored', (
        tester,
      ) async {
        final bounded = createController(
          maxDate: DateConstraint.fixed(DateTime(2024, 6, 30)),
        );
        var busyAtHaptic = false;

        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: bounded,
                onHapticFeedback: (_) {
                  busyAtHaptic = bounded.isNavigating;
                  bounded.goToMonth(DateTime(2024, 5, 1));
                },
              ),
            ),
          ),
        );

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pumpAndSettle();

        expect(busyAtHaptic, isTrue);
        expect(bounded.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(bounded.isNavigating, isFalse);
      });

      testWidgets('with gestures off, a fling does not move the calendar', (
        tester,
      ) async {
        await tester.pumpWidget(app(page(calendar(gesturesEnabled: false))));

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(controller.isNavigating, isFalse);
      });

      testWidgets('a request made while a drag is held is ignored', (
        tester,
      ) async {
        await tester.pumpWidget(app(page(calendar())));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        // 60 px: below the threshold, so the swipe does not move.
        await gesture.moveBy(const Offset(0, -60));
        controller.goToMonth(DateTime(2024, 9, 1));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(controller.isNavigating, isFalse);
        expect(find.byKey(const Key('6-1')), findsOneWidget);
      });

      testWidgets('is navigating while a drag is held', (tester) async {
        await tester.pumpWidget(app(page(calendar())));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -50));

        expect(controller.isNavigating, isTrue);

        await gesture.up();
        await tester.pump();

        expect(controller.isNavigating, isFalse);
      });

      testWidgets('a restricted swipe snaps back even if its month becomes '
          'allowed during the drag', (tester) async {
        final bounded = createController(
          maxDate: DateConstraint.fixed(DateTime(2024, 6, 30)),
        );

        // A low threshold, so the handler counts the drag as complete.
        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: bounded,
                style: const CalendarStyle(dragProgressThreshold: 0.01),
              ),
            ),
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        for (var move = 0; move < 3; move++) {
          await gesture.moveBy(const Offset(0, -20));
          await tester.pump();
        }
        bounded.setBounds(null, null);
        await gesture.up();
        await tester.pumpAndSettle();

        expect(bounded.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(bounded.isNavigating, isFalse);
      });

      testWidgets('a swipe whose month becomes forbidden during the drag '
          'snaps back', (tester) async {
        await tester.pumpWidget(app(page(calendar())));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -50));
        await gesture.moveBy(const Offset(0, -150));
        controller.setBounds(null, DateConstraint.fixed(DateTime(2024, 6, 30)));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(controller.isNavigating, isFalse);
      });

      testWidgets('a swipe whose month becomes forbidden before it lands '
          'snaps back', (tester) async {
        await tester.pumpWidget(app(page(calendar())));

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        // Released: July is shown, and the report comes after the next frame.
        controller.setBounds(null, DateConstraint.fixed(DateTime(2024, 6, 30)));
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(controller.isNavigating, isFalse);
        expect(find.byKey(const Key('6-15')), findsOneWidget);
      });

      testWidgets('a drag that begins after a request, before the rebuild, '
          'is ignored', (tester) async {
        final haptics = <CalendarHapticType>[];

        await tester.pumpWidget(
          app(page(calendar(onHapticFeedback: haptics.add))),
        );

        controller.goToMonth(DateTime(2024, 7, 1));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -50));
        await gesture.moveBy(const Offset(0, -150));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(controller.isNavigating, isFalse);
        expect(haptics, isEmpty);
      });
    });

    group('swipes out of a forbidden month', () {
      testWidgets('a fling toward the allowed range lands on its nearest '
          'month, with no haptic', (tester) async {
        final haptics = <CalendarHapticType>[];
        final december = createController(initialMonth: DateTime(2024, 12, 1));

        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: december,
                onHapticFeedback: haptics.add,
              ),
            ),
          ),
        );
        december.setBounds(null, DateConstraint.fixed(DateTime(2024, 9, 30)));

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, 200),
          1000,
        );
        await tester.pumpAndSettle();

        expect(december.currentMonth, equals(DateTime(2024, 9, 1)));
        expect(find.byKey(const Key('9-1')), findsOneWidget);
        expect(haptics, isEmpty);
      });

      testWidgets('a fling away from the allowed range stays and signals '
          'once', (tester) async {
        final haptics = <CalendarHapticType>[];
        final december = createController(initialMonth: DateTime(2024, 12, 1));

        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: december,
                onHapticFeedback: haptics.add,
              ),
            ),
          ),
        );
        december.setBounds(null, DateConstraint.fixed(DateTime(2024, 9, 30)));

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pumpAndSettle();

        expect(december.currentMonth, equals(DateTime(2024, 12, 1)));
        expect(haptics, equals([CalendarHapticType.navigationRestricted]));
      });
    });

    testWidgets('a request past a bound stays, with no haptic', (tester) async {
      final haptics = <CalendarHapticType>[];
      final bounded = createController(
        maxDate: DateConstraint.fixed(DateTime(2024, 6, 30)),
      );

      await tester.pumpWidget(
        app(
          page(
            calendar(
              calendarController: bounded,
              onHapticFeedback: haptics.add,
            ),
          ),
        ),
      );

      bounded.nextMonth();
      await tester.pumpAndSettle();

      expect(bounded.currentMonth, equals(DateTime(2024, 6, 1)));
      expect(haptics, isEmpty);
    });

    group('animated swipes', () {
      testWidgets('a fling up turns the page to the next month', (
        tester,
      ) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsOneWidget);

        await tester.pumpAndSettle();

        expect(animated.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(animated.isNavigating, isFalse);
      });

      testWidgets('turning animations off as the swipe starts leaves the '
          'swipe animated', (tester) async {
        final animated = createController(animationsEnabled: true);
        animated.addListener(() {
          if (animated.isNavigating) animated.animationsEnabled = false;
        });

        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsOneWidget);

        await tester.pumpAndSettle();

        expect(animated.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(animated.isNavigating, isFalse);
      });

      testWidgets('the page follows the finger linearly', (tester) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
        await tester.pump();
        await gesture.moveBy(const Offset(0, -56));
        await tester.pump();

        // 76 px of a 280 px drag box (0.7 of 400 px), drawn as is, not
        // through the default decelerating curve.
        final turn = tester.widget<PageTurnAnimation>(
          find.byType(PageTurnAnimation),
        );
        expect(turn.animation.value, closeTo(76 / 280, 0.0001));

        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('a navigation\'s page turns along the style\'s curve, '
          'after the curve changes', (tester) async {
        final animated = createController(animationsEnabled: true);
        Widget withCurve(Curve curve) {
          return app(
            page(
              calendar(
                calendarController: animated,
                style: CalendarStyle(
                  animationDuration: const Duration(milliseconds: 600),
                  animationCurve: curve,
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(withCurve(Curves.decelerate));
        await tester.pumpWidget(withCurve(Curves.easeIn));

        animated.goToMonth(DateTime(2024, 7, 1));
        await tester.pump();
        await tester.pump();
        // The turn's first frame, then half its duration.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final turn = tester.widget<PageTurnAnimation>(
          find.byType(PageTurnAnimation),
        );
        expect(
          turn.animation.value,
          closeTo(Curves.easeIn.transform(0.5), 0.0001),
        );

        await tester.pumpAndSettle();
      });

      testWidgets(
        "a released swipe's page turns back along the style's curve",
        (tester) async {
          final animated = createController(animationsEnabled: true);

          await tester.pumpWidget(
            app(
              page(
                calendar(
                  calendarController: animated,
                  style: const CalendarStyle(
                    animationDuration: Duration(milliseconds: 600),
                    animationCurve: Curves.easeIn,
                  ),
                ),
              ),
            ),
          );

          // 76 px of the 280 px drag box: below the threshold, so the page
          // turns back from 76 / 280.
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(FlipCalendar)),
          );
          await gesture.moveBy(const Offset(0, -20));
          await tester.pump();
          await tester.pump();
          await gesture.moveBy(const Offset(0, -56));
          await tester.pump();
          await gesture.up();

          // The turn back's first frame, then half its duration: the part of
          // 600 ms that 76 / 280 of a turn takes.
          await tester.pump();
          final back = const Duration(milliseconds: 600) * (76 / 280);
          await tester.pump(back ~/ 2);

          final turn = tester.widget<PageTurnAnimation>(
            find.byType(PageTurnAnimation),
          );
          expect(
            turn.animation.value,
            closeTo(76 / 280 * (1 - Curves.easeIn.transform(0.5)), 0.001),
          );

          await tester.pumpAndSettle();
          expect(animated.currentMonth, equals(DateTime(2024, 6, 1)));
        },
      );

      testWidgets('a restricted drag lifts the page no more than 0.02, even '
          'before the next frame, over the month it cannot reach', (
        tester,
      ) async {
        final animated = createController(
          maxDate: DateConstraint.fixed(DateTime(2024, 6, 30)),
          animationsEnabled: true,
        );

        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -20));
        await gesture.moveBy(const Offset(0, -100));
        await gesture.moveBy(const Offset(0, -100));
        await tester.pump();
        await tester.pump();

        final turn = tester.widget<PageTurnAnimation>(
          find.byType(PageTurnAnimation),
        );
        expect(turn.animation.value, lessThanOrEqualTo(0.02));
        // Under the lifted page (an image of June) is July.
        expect(find.byKey(const Key('7-1')), findsOneWidget);
        expect(find.byKey(const Key('6-15')), findsNothing);

        await gesture.up();
        await tester.pumpAndSettle();

        expect(animated.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(animated.isNavigating, isFalse);
      });

      testWidgets('a drag below the threshold snaps back', (tester) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        // 60 px of the 280 px drag box: progress 0.21, below 0.3.
        await tester.drag(find.byType(FlipCalendar), const Offset(0, -60));
        await tester.pumpAndSettle();

        expect(animated.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(animated.isNavigating, isFalse);
      });

      testWidgets("a swipe's page turn lasts the style's animationDuration", (
        tester,
      ) async {
        final animated = createController(animationsEnabled: true);
        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: animated,
                style: const CalendarStyle(
                  animationDuration: Duration(seconds: 1),
                ),
              ),
            ),
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -70));
        await tester.pump();
        await tester.pump();
        // 140 px of the 280 px drag box: released at 0.5, half the turn left.
        await gesture.moveBy(const Offset(0, -70));
        await gesture.up();
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 450));
        expect(find.byType(PageTurnAnimation), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(PageTurnAnimation), findsNothing);
        expect(find.byKey(const Key('7-1')), findsOneWidget);
      });

      testWidgets('a drag released below the threshold while the page turns '
          'turns it back', (tester) async {
        final animated = createController(animationsEnabled: true);
        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump();
        await tester.pump();
        final turn = find.byType(PageTurnAnimation);
        final atRelease = tester
            .widget<PageTurnAnimation>(turn)
            .animation
            .value;

        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          tester.widget<PageTurnAnimation>(turn).animation.value,
          lessThan(atRelease),
        );
        await tester.pumpAndSettle();
        expect(animated.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(animated.isNavigating, isFalse);
      });

      testWidgets('a fling toward a forbidden month stays and signals once', (
        tester,
      ) async {
        final haptics = <CalendarHapticType>[];
        final animated = createController(
          maxDate: DateConstraint.fixed(DateTime(2024, 6, 30)),
          animationsEnabled: true,
        );

        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: animated,
                onHapticFeedback: haptics.add,
              ),
            ),
          ),
        );

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pumpAndSettle();

        expect(animated.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(animated.isNavigating, isFalse);
        expect(haptics, equals([CalendarHapticType.navigationRestricted]));
      });

      testWidgets('a slow drag past the threshold turns the page', (
        tester,
      ) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        // About 33 px/s, too slow for a flick, so the progress decides:
        // 200/280, above the 0.3 threshold.
        await tester.timedDrag(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          const Duration(seconds: 6),
        );
        await tester.pumpAndSettle();

        expect(animated.currentMonth, equals(DateTime(2024, 7, 1)));
      });

      testWidgets('a second fling during the page turn is ignored', (
        tester,
      ) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsOneWidget);

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pumpAndSettle();

        expect(animated.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(animated.isNavigating, isFalse);
      });

      testWidgets('a drag on the calendar during a page turn is the '
          'calendar\'s, and is ignored', (tester) async {
        final animated = createController(animationsEnabled: true);
        final pages = PageController();
        addTearDown(pages.dispose);

        await tester.pumpWidget(
          app(
            PageView(
              controller: pages,
              children: [
                calendar(
                  calendarController: animated,
                  boundEdge: PageTurnEdge.left,
                ),
                const SizedBox(),
              ],
            ),
          ),
        );

        animated.goToMonth(DateTime(2024, 7, 1));
        await tester.pump();
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsOneWidget);

        await tester.drag(find.byType(FlipCalendar), const Offset(-400, 0));
        await tester.pumpAndSettle();

        expect(pages.page, equals(0));
        expect(animated.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(animated.isNavigating, isFalse);
      });

      testWidgets('a drag that turns the page all the way lands', (
        tester,
      ) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
        await tester.pump();
        // 340 px in all, more than the 280 px drag box, so the page is fully
        // turned at release.
        for (var move = 0; move < 8; move++) {
          await gesture.moveBy(const Offset(0, -40));
          await tester.pump();
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(animated.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(animated.isNavigating, isFalse);
      });
    });

    group('controllers', () {
      testWidgets('a new controller shows its month and plays only its '
          'navigations', (tester) async {
        final september = createController(initialMonth: DateTime(2024, 9, 1));

        await tester.pumpWidget(app(page(calendar())));
        await tester.pumpWidget(
          app(page(calendar(calendarController: september))),
        );

        expect(find.byKey(const Key('9-1')), findsOneWidget);

        controller.goToMonth(DateTime(2024, 7, 1));

        expect(controller.isNavigating, isFalse);

        await tester.pump();

        expect(find.byKey(const Key('9-1')), findsOneWidget);

        september.goToMonth(DateTime(2024, 10, 1));

        expect(september.isNavigating, isTrue);

        await tester.pump();

        expect(september.isNavigating, isFalse);
        expect(find.byKey(const Key('10-1')), findsOneWidget);
      });

      testWidgets("a page turn's capture scheduled before the controller is "
          'replaced does nothing', (tester) async {
        final first = createController(animationsEnabled: true);
        final second = createController(animationsEnabled: true);
        var secondNotified = 0;
        second.addListener(() => secondNotified++);
        await tester.pumpWidget(app(page(calendar(calendarController: first))));

        // The capture is scheduled for the frame that replaces the controller.
        first.goToMonth(DateTime(2024, 7, 1));
        await tester.pumpWidget(
          app(page(calendar(calendarController: second))),
        );
        await tester.pumpAndSettle();

        expect(secondNotified, 0);
        expect(find.byType(PageTurnAnimation), findsNothing);
        expect(find.byKey(const Key('6-1')), findsOneWidget);
      });

      testWidgets('a report scheduled before the controller is replaced is '
          'dropped', (tester) async {
        final second = createController();
        var secondNotified = 0;
        second.addListener(() => secondNotified++);
        await tester.pumpWidget(app(page(calendar())));

        // With animations off the navigation reports after the next frame:
        // the frame that replaces the controller.
        controller.goToMonth(DateTime(2024, 7, 1));
        await tester.pumpWidget(
          app(page(calendar(calendarController: second))),
        );
        await tester.pumpAndSettle();

        expect(secondNotified, 0);
        expect(second.isNavigating, isFalse);
      });

      testWidgets('a controller replaced mid-flip is left at rest', (
        tester,
      ) async {
        final first = createController(animationsEnabled: true);
        final second = createController(animationsEnabled: true);

        await tester.pumpWidget(app(page(calendar(calendarController: first))));
        first.goToMonth(DateTime(2024, 8, 1));
        await tester.pump();
        await tester.pump();
        expect(find.byType(PageTurnAnimation), findsOneWidget);
        expect(first.isNavigating, isTrue);

        await tester.pumpWidget(
          app(page(calendar(calendarController: second))),
        );

        expect(first.isNavigating, isFalse);
      });

      testWidgets('a calendar moved with a GlobalKey mid-flip rests and keeps '
          'following its controller', (tester) async {
        final animated = createController(animationsEnabled: true);
        final keyedPage = KeyedSubtree(
          key: GlobalKey(),
          child: page(calendar(calendarController: animated)),
        );

        await tester.pumpWidget(app(Column(children: [keyedPage])));
        animated.goToMonth(DateTime(2024, 8, 1));
        await tester.pump();
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsOneWidget);

        await tester.pumpWidget(app(Row(children: [keyedPage])));
        await tester.pumpAndSettle();

        expect(animated.isNavigating, isFalse);
        expect(find.byKey(const Key('8-1')), findsOneWidget);

        animated.goToMonth(DateTime(2024, 9, 1));
        await tester.pump();
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsOneWidget);

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('9-1')), findsOneWidget);
      });
    });

    group('two calendars on one controller', () {
      Widget twoCalendars(CalendarController shared) {
        return app(
          Row(
            children: [
              page(calendar(calendarController: shared)),
              page(calendar(calendarController: shared)),
            ],
          ),
        );
      }

      testWidgets('with animations off, both calendars show the month after '
          'one frame, at rest', (tester) async {
        await tester.pumpWidget(twoCalendars(controller));

        controller.goToMonth(DateTime(2024, 7, 1));

        expect(controller.isNavigating, isTrue);

        await tester.pump();

        expect(controller.isNavigating, isFalse);
        expect(find.byKey(const Key('7-1')), findsNWidgets(2));
      });

      testWidgets('a swipe on one calendar is followed by the other', (
        tester,
      ) async {
        await tester.pumpWidget(twoCalendars(controller));

        await tester.fling(
          find.byType(FlipCalendar).first,
          const Offset(0, -200),
          1000,
        );
        await tester.pump();

        expect(find.byKey(const Key('7-1')), findsOneWidget);
        // The other calendar owes the month the swipe landed on.
        expect(controller.isNavigating, isTrue);

        await tester.pump();

        expect(find.byKey(const Key('7-1')), findsNWidgets(2));
        expect(controller.isNavigating, isFalse);
      });

      testWidgets('an animated navigation ends once the slower calendar has '
          'turned its page', (tester) async {
        final animated = createController(animationsEnabled: true);
        Widget turning(Duration duration) {
          return page(
            calendar(
              calendarController: animated,
              style: CalendarStyle(animationDuration: duration),
            ),
          );
        }

        await tester.pumpWidget(
          app(
            Row(
              children: [
                turning(const Duration(milliseconds: 100)),
                turning(const Duration(seconds: 1)),
              ],
            ),
          ),
        );

        animated.goToMonth(DateTime(2024, 7, 1));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(PageTurnAnimation), findsOneWidget);
        expect(animated.isNavigating, isTrue);

        await tester.pumpAndSettle();

        expect(animated.isNavigating, isFalse);
      });

      testWidgets('an animated navigation turns both pages', (tester) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(twoCalendars(animated));

        animated.goToMonth(DateTime(2024, 7, 1));
        await tester.pump();
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsNWidgets(2));

        await tester.pumpAndSettle();

        expect(animated.isNavigating, isFalse);
      });
    });

    group('calendars not on screen', () {
      /// Two tabs, the second a calendar on [calendarController]; [index] is
      /// the tab shown.
      Widget tabs({
        required int index,
        required CalendarController calendarController,
      }) {
        return app(
          IndexedStack(
            index: index,
            children: [
              const SizedBox(),
              page(calendar(calendarController: calendarController)),
            ],
          ),
        );
      }

      testWidgets('a hidden calendar changes month without a page turn, '
          'request after request', (tester) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(tabs(index: 0, calendarController: animated));

        for (final month in [DateTime(2024, 10, 1), DateTime(2024, 12, 1)]) {
          animated.goToMonth(month);
          await tester.pump();

          expect(animated.isNavigating, isFalse, reason: '$month');

          await tester.pump();

          expect(
            find.byType(PageTurnAnimation, skipOffstage: false),
            findsNothing,
            reason: '$month',
          );
          expect(
            find.byKey(Key('${month.month}-1'), skipOffstage: false),
            findsOneWidget,
            reason: '$month',
          );
        }
      });

      testWidgets('whenShown lets a hidden calendar turn its pages once '
          'shown', (tester) async {
        final july = createController(
          initialMonth: DateTime(2024, 7, 1),
          animationsEnabled: true,
        );
        var shown = false;
        var atRest = false;

        await tester.pumpWidget(tabs(index: 0, calendarController: july));

        july.whenShown().then((_) => shown = true);
        await tester.pump();

        expect(shown, isFalse);

        await tester.pumpWidget(tabs(index: 1, calendarController: july));

        expect(shown, isTrue);
        expect(
          july.monthsOnWayTo(DateTime(2024, 9, 1)),
          equals([
            DateTime(2024, 7, 1),
            DateTime(2024, 8, 1),
            DateTime(2024, 9, 1),
          ]),
        );

        july.goToMonth(DateTime(2024, 9, 1));
        july.whenAtRest().then((_) => atRest = true);
        await tester.pump();
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsOneWidget);

        await tester.pumpAndSettle();

        expect(atRest, isTrue);
        expect(find.byKey(const Key('9-1')), findsOneWidget);
      });

      testWidgets('whenShown called before any calendar is built completes '
          "after the calendar's first frame", (tester) async {
        var shown = false;
        controller.whenShown().then((_) => shown = true);

        await tester.pumpWidget(app(page(calendar())));

        expect(shown, isTrue);
      });

      testWidgets('whenShown completes after one frame for a calendar on '
          'screen', (tester) async {
        var shown = false;

        await tester.pumpWidget(app(page(calendar())));

        controller.whenShown().then((_) => shown = true);
        await tester.pump();

        expect(shown, isTrue);
      });

      testWidgets('a calendar with paused animations changes month without a '
          'page turn', (tester) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(
            TickerMode(
              enabled: false,
              child: page(calendar(calendarController: animated)),
            ),
          ),
        );

        animated.goToMonth(DateTime(2024, 7, 1));
        await tester.pump();

        expect(animated.isNavigating, isFalse);

        await tester.pump();

        expect(find.byKey(const Key('7-1')), findsOneWidget);
      });

      testWidgets('a swipe on a calendar with paused animations lands without '
          'a page turn', (tester) async {
        final animated = createController(animationsEnabled: true);
        await tester.pumpWidget(
          app(
            TickerMode(
              enabled: false,
              child: page(calendar(calendarController: animated)),
            ),
          ),
        );

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        await tester.pump();
        expect(find.byType(PageTurnAnimation), findsNothing);
        await tester.pumpAndSettle();

        expect(animated.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(animated.isNavigating, isFalse);
        expect(find.byKey(const Key('7-1')), findsOneWidget);
      });

      testWidgets('whenShown completes once paused animations resume', (
        tester,
      ) async {
        final animated = createController(animationsEnabled: true);
        // The same widget in both builds, so the ticker mode is all that
        // changes.
        final calendarPage = page(calendar(calendarController: animated));
        var shown = false;

        await tester.pumpWidget(
          app(TickerMode(enabled: false, child: calendarPage)),
        );

        animated.whenShown().then((_) => shown = true);
        await tester.pump();
        await tester.pump();

        expect(shown, isFalse);

        await tester.pumpWidget(
          app(TickerMode(enabled: true, child: calendarPage)),
        );
        await tester.pump();

        expect(shown, isTrue);
      });

      testWidgets('a turn whose animations pause stops where it is, stays '
          'busy, and finishes once they resume', (tester) async {
        final animated = createController(animationsEnabled: true);
        // The same widget in every build, so the ticker mode is all that
        // changes.
        final calendarPage = page(calendar(calendarController: animated));
        double turnValue() {
          return tester
              .widget<PageTurnAnimation>(find.byType(PageTurnAnimation))
              .animation
              .value;
        }

        await tester.pumpWidget(
          app(TickerMode(enabled: true, child: calendarPage)),
        );

        // The capture frame, the turn's first frame, then 100 ms of it.
        animated.nextMonth();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final paused = turnValue();
        expect(paused, greaterThan(0));

        await tester.pumpWidget(
          app(TickerMode(enabled: false, child: calendarPage)),
        );
        await tester.pump(const Duration(seconds: 5));

        expect(turnValue(), equals(paused));
        expect(animated.isNavigating, isTrue);

        await tester.pumpWidget(
          app(TickerMode(enabled: true, child: calendarPage)),
        );
        await tester.pumpAndSettle();

        expect(animated.isNavigating, isFalse);
        expect(find.byKey(const Key('7-1')), findsOneWidget);
      });

      testWidgets('whenShown does not count a paint made while animations '
          'were paused', (tester) async {
        final animated = createController(animationsEnabled: true);
        final calendarPage = page(calendar(calendarController: animated));
        var shown = false;

        Widget host({required bool running, required bool offstage}) {
          return app(
            TickerMode(
              enabled: running,
              child: Offstage(offstage: offstage, child: calendarPage),
            ),
          );
        }

        await tester.pumpWidget(host(running: false, offstage: false));
        animated.whenShown().then((_) => shown = true);
        await tester.pump();
        await tester.pump();
        expect(shown, isFalse);

        // Animations resume as the calendar goes offstage.
        await tester.pumpWidget(host(running: true, offstage: true));
        await tester.pump();
        expect(shown, isFalse);

        await tester.pumpWidget(host(running: true, offstage: false));
        await tester.pump();
        expect(shown, isTrue);
      });

      testWidgets('a calendar that leaves its controller drops its on-screen '
          'check', (tester) async {
        final first = _CountingController(
          initialMonth: DateTime(2024, 6, 1),
          clock: clock,
        );
        final second = _CountingController(
          initialMonth: DateTime(2024, 6, 1),
          clock: clock,
        );
        controllers.addAll([first, second]);
        Widget host(CalendarController shared, {required bool offstage}) {
          return app(
            Offstage(
              offstage: offstage,
              child: page(calendar(calendarController: shared)),
            ),
          );
        }

        await tester.pumpWidget(host(first, offstage: true));
        first.whenShown();
        await tester.pump();
        await tester.pumpWidget(host(second, offstage: true));
        await tester.pumpWidget(host(second, offstage: false));
        await tester.pump();

        expect(first.onScreenReports, 0);
        expect(second.onScreenReports, 0);
      });

      testWidgets('a calendar moved under paused animations changes month '
          'without a page turn', (tester) async {
        final animated = createController(animationsEnabled: true);
        final key = GlobalKey();
        Widget host({required bool paused}) {
          final calendarPage = KeyedSubtree(
            key: key,
            child: page(calendar(calendarController: animated)),
          );
          return app(
            Row(
              children: [
                TickerMode(
                  enabled: true,
                  child: paused ? const SizedBox() : calendarPage,
                ),
                TickerMode(
                  enabled: false,
                  child: paused ? calendarPage : const SizedBox(),
                ),
              ],
            ),
          );
        }

        await tester.pumpWidget(host(paused: false));
        await tester.pumpWidget(host(paused: true));

        animated.goToMonth(DateTime(2024, 7, 1));
        await tester.pump();
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsNothing);
        expect(find.byKey(const Key('7-1')), findsOneWidget);
        expect(animated.isNavigating, isFalse);
      });

      testWidgets('a calendar answers an on-screen check once', (tester) async {
        final counting = _CountingController(
          initialMonth: DateTime(2024, 6, 1),
          clock: clock,
        );
        controllers.add(counting);
        await tester.pumpWidget(
          app(page(calendar(calendarController: counting))),
        );

        counting.whenShown();
        await tester.pump();
        expect(counting.onScreenReports, 1);

        // A page turn paints the calendar in every frame.
        counting.nextMonth();
        await tester.pumpAndSettle();
        expect(counting.onScreenReports, 1);
      });
    });

    group('navigations', () {
      testWidgets('a sequential navigation turns to each month on the way', (
        tester,
      ) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        animated.goToMonth(DateTime(2024, 8, 1));
        await tester.pump();
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsOneWidget);
        expect(find.byKey(const Key('7-1')), findsOneWidget);
        expect(find.byKey(const Key('8-1')), findsNothing);

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('8-1')), findsOneWidget);
      });

      testWidgets('a sequential navigation shares the duration among its '
          'turns', (tester) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: animated,
                style: const CalendarStyle(
                  animationDuration: Duration(milliseconds: 600),
                ),
              ),
            ),
          ),
        );

        animated.goToMonth(DateTime(2024, 8, 1));
        await tester.pump();
        await tester.pump();
        // Two turns of 300 ms each: at 290 ms the first still turns...
        await tester.pump(const Duration(milliseconds: 290));
        await tester.pump();

        expect(find.byKey(const Key('8-1')), findsNothing);

        // ...and by 450 ms it has ended, and after the second's capture frame
        // the second turns over the August page.
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pump();

        expect(find.byKey(const Key('8-1')), findsOneWidget);

        await tester.pumpAndSettle();

        expect(animated.isNavigating, isFalse);
      });

      testWidgets('a sequential navigation divides the duration among its '
          'turns to the microsecond', (tester) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: animated,
                style: const CalendarStyle(
                  animationDuration: Duration(milliseconds: 3),
                ),
              ),
            ),
          ),
        );

        animated.goToMonth(DateTime(2024, 8, 1));
        await tester.pump();
        await tester.pump();
        // Two turns of 1.5 ms each: by 1.6 ms the first has ended, and after
        // the second's capture frame the second turns over the August page.
        await tester.pump(const Duration(microseconds: 1600));
        await tester.pump();

        expect(find.byKey(const Key('8-1')), findsOneWidget);

        await tester.pumpAndSettle();

        expect(animated.isNavigating, isFalse);
      });

      testWidgets('a direct jump turns one page', (tester) async {
        final animated = createController(animationsEnabled: true);
        animated.multiMonthAnimationMode = MultiMonthAnimationMode.directJump;
        // Keys with the year: June 2024 and June 2025 share the file's keys.
        Widget dayWithYear(BuildContext context, CalendarDayData data) {
          final date = data.date;
          return Text(
            '${date.day}',
            key: data.isCurrentMonth
                ? Key('${date.year}-${date.month}-${date.day}')
                : null,
          );
        }

        await tester.pumpWidget(
          app(
            page(
              calendar(calendarController: animated, dayBuilder: dayWithYear),
            ),
          ),
        );

        animated.goToMonth(DateTime(2025, 6, 1));
        await tester.pump();
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsOneWidget);
        expect(find.byKey(const Key('2025-6-1')), findsOneWidget);
        expect(find.byKey(const Key('2024-7-1')), findsNothing);

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('2025-6-1')), findsOneWidget);
        expect(animated.isNavigating, isFalse);
      });

      testWidgets('each page turn captures one image, and disposes it', (
        tester,
      ) async {
        final created = <ui.Image>[];
        final disposed = <ui.Image>[];
        ui.Image.onCreate = created.add;
        ui.Image.onDispose = disposed.add;
        addTearDown(() {
          ui.Image.onCreate = null;
          ui.Image.onDispose = null;
        });
        final animated = createController(animationsEnabled: true);
        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        animated.nextMonth();
        await tester.pumpAndSettle();
        animated.previousMonth();
        await tester.pumpAndSettle();

        expect(created, hasLength(2));
        expect(disposed, unorderedEquals(created));
      });

      testWidgets("a page turn's image is disposed when the calendar is "
          'removed during the turn', (tester) async {
        final created = <ui.Image>[];
        final disposed = <ui.Image>[];
        ui.Image.onCreate = created.add;
        ui.Image.onDispose = disposed.add;
        addTearDown(() {
          ui.Image.onCreate = null;
          ui.Image.onDispose = null;
        });
        final animated = createController(animationsEnabled: true);
        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        animated.nextMonth();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(created, hasLength(1));

        await tester.pumpWidget(app(const SizedBox()));

        expect(disposed, created);
      });

      testWidgets('a forward turn curls the page turned from away, over the '
          'page turned to', (tester) async {
        final animated = createController(animationsEnabled: true);
        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        animated.nextMonth();
        await tester.pump();
        // The capture frame: only the page turned from is built, and captured.
        expect(find.byKey(const Key('7-1')), findsNothing);
        await tester.pump(const Duration(milliseconds: 100));

        final turn = tester.widget<PageTurnAnimation>(
          find.byType(PageTurnAnimation),
        );
        expect(turn.direction, PageTurnDirection.forward);
        expect(find.byKey(const Key('7-1')), findsOneWidget);
        expect(find.byKey(const Key('6-1')), findsNothing);
      });

      testWidgets('a backward turn curls the page turned to in, over the page '
          'turned from', (tester) async {
        final animated = createController(animationsEnabled: true);
        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        animated.previousMonth();
        await tester.pump();
        // The capture frame: the page turned to is captured, under the page
        // shown, so it has the capture's RepaintBoundary as well.
        int boundariesAround(String key) {
          return find
              .ancestor(
                of: find.byKey(Key(key)),
                matching: find.byType(RepaintBoundary),
              )
              .evaluate()
              .length;
        }

        expect(boundariesAround('5-1'), boundariesAround('6-1') + 1);
        await tester.pump(const Duration(milliseconds: 100));

        final turn = tester.widget<PageTurnAnimation>(
          find.byType(PageTurnAnimation),
        );
        expect(turn.direction, PageTurnDirection.backward);
        expect(find.byKey(const Key('6-1')), findsOneWidget);
        expect(find.byKey(const Key('5-1')), findsNothing);
      });

      testWidgets("a page turn uses the style's pageTurnStyle and the "
          "calendar's boundEdge", (tester) async {
        final animated = createController(animationsEnabled: true);
        const pageTurnStyle = PageTurnStyle(segments: 7);

        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: animated,
                style: const CalendarStyle(pageTurnStyle: pageTurnStyle),
                boundEdge: PageTurnEdge.left,
              ),
            ),
          ),
        );

        animated.nextMonth();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final turn = tester.widget<PageTurnAnimation>(
          find.byType(PageTurnAnimation),
        );
        expect(turn.style, equals(pageTurnStyle));
        expect(turn.edge, equals(PageTurnEdge.left));

        await tester.pumpAndSettle();
      });

      testWidgets('a navigation with a zero duration ends on its month, at '
          'rest', (tester) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: animated,
                style: const CalendarStyle(animationDuration: Duration.zero),
              ),
            ),
          ),
        );

        animated.goToMonth(DateTime(2024, 9, 1));
        await tester.pumpAndSettle();

        expect(animated.isNavigating, isFalse);
        expect(find.byKey(const Key('9-1')), findsOneWidget);
      });

      testWidgets('a calendar removed mid-flip ends the navigation', (
        tester,
      ) async {
        final animated = createController(animationsEnabled: true);
        var atRest = false;

        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );

        animated.goToMonth(DateTime(2024, 8, 1));
        animated.whenAtRest().then((_) => atRest = true);
        await tester.pump();
        await tester.pump();

        await tester.pumpWidget(app(const SizedBox()));

        expect(animated.isNavigating, isFalse);
        expect(atRest, isTrue);
      });

      testWidgets('a page with no size changes month without a page turn', (
        tester,
      ) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(
            SizedBox.shrink(
              child: calendar(
                calendarController: animated,
                style: const CalendarStyle(
                  weekdayHeaderHeight: 0,
                  gridLineWidth: 0,
                ),
              ),
            ),
          ),
        );

        animated.goToMonth(DateTime(2024, 7, 1));
        await tester.pump();
        // The capture found no size: July is drawn in the next frame, and
        // reported after it.
        expect(animated.isNavigating, isTrue);
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsNothing);
        expect(animated.isNavigating, isFalse);
        expect(find.byKey(const Key('7-1')), findsOneWidget);
      });

      testWidgets('a navigation reports after the frame that shows its month', (
        tester,
      ) async {
        final animated = createController(animationsEnabled: true);
        await tester.pumpWidget(
          app(page(calendar(calendarController: animated))),
        );
        bool? mayShownAtRest;

        // Backward, so May is built only once the turn has ended.
        animated.previousMonth();
        animated.whenAtRest().then(
          (_) => mayShownAtRest = find
              .byKey(const Key('5-1'))
              .evaluate()
              .isNotEmpty,
        );
        await tester.pumpAndSettle();

        expect(mayShownAtRest, isTrue);
      });

      testWidgets('a navigation requested in a build outside any frame ends '
          'on its month, at rest', (tester) async {
        final request = ValueNotifier(false);
        addTearDown(request.dispose);
        await tester.pumpWidget(
          app(
            Column(
              children: [
                page(calendar()),
                ValueListenableBuilder<bool>(
                  valueListenable: request,
                  builder: (context, requested, child) {
                    if (requested) controller.nextMonth();
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );

        // Flutter runs an app's first build outside any frame, where the
        // controller notifies at once; buildScope builds the same way here.
        request.value = true;
        tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
        // The calendar's redraw inside that build fails Flutter's debug check.
        expect(
          tester.takeException(),
          isA<FlutterError>().having(
            (error) => error.message,
            'message',
            startsWith('setState() or markNeedsBuild() called during build.'),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(controller.isNavigating, isFalse);
        expect(find.byKey(const Key('7-1')), findsOneWidget);
      });

      testWidgets('an animated navigation requested in a build outside any '
          'frame ends on its month without a page turn', (tester) async {
        final animated = createController(animationsEnabled: true);
        final request = ValueNotifier(false);
        addTearDown(request.dispose);
        await tester.pumpWidget(
          app(
            Column(
              children: [
                page(calendar(calendarController: animated)),
                ValueListenableBuilder<bool>(
                  valueListenable: request,
                  builder: (context, requested, child) {
                    if (requested) animated.nextMonth();
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );

        // As in the test above: the redraw fails, so the pages for the page
        // turn's capture are never built.
        request.value = true;
        tester.binding.buildOwner!.buildScope(tester.binding.rootElement!);
        expect(tester.takeException(), isA<FlutterError>());
        await tester.pump();

        expect(find.byType(PageTurnAnimation), findsNothing);
        await tester.pumpAndSettle();
        expect(animated.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(animated.isNavigating, isFalse);
        expect(find.byKey(const Key('7-1')), findsOneWidget);
      });

      testWidgets("a keyboard-inset change after a page turn doesn't rebuild "
          'the calendar', (tester) async {
        final animated = createController(animationsEnabled: true);
        final inset = ValueNotifier(0.0);
        addTearDown(inset.dispose);
        var day15Builds = 0;
        // The same widget in every build: only the inset changes around it.
        final calendarPage = page(
          calendar(
            calendarController: animated,
            dayBuilder: (context, data) {
              if (data.date.day == 15) day15Builds++;
              return dayCell(context, data);
            },
          ),
        );
        await tester.pumpWidget(
          app(
            ValueListenableBuilder<double>(
              valueListenable: inset,
              builder: (context, bottom, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(viewInsets: EdgeInsets.only(bottom: bottom)),
                child: child!,
              ),
              child: calendarPage,
            ),
          ),
        );
        animated.nextMonth();
        await tester.pumpAndSettle();
        day15Builds = 0;

        inset.value = 100;
        await tester.pump();

        expect(day15Builds, 0);
      });

      /// Pumps one frame and returns the errors Flutter reported in it.
      Future<List<FlutterErrorDetails>> pumpReportingErrors(
        WidgetTester tester,
      ) async {
        final errors = <FlutterErrorDetails>[];
        final reportError = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          await tester.pump();
        } finally {
          FlutterError.onError = reportError;
        }
        return errors;
      }

      void expectCaptureError(List<FlutterErrorDetails> errors) {
        expect(errors, hasLength(1));
        expect(errors.single.library, 'flip_calendar');
        expect(
          errors.single.context.toString(),
          'while capturing a calendar page for a page turn',
        );
      }

      testWidgets('a capture that throws ends the navigation without a page '
          'turn, and is reported', (tester) async {
        final animated = createController(animationsEnabled: true);
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(devicePixelRatio: 0),
                child: page(calendar(calendarController: animated)),
              ),
            ),
          ),
        );

        animated.nextMonth();
        final errors = await pumpReportingErrors(tester);

        expectCaptureError(errors);
        expect(
          errors.single.exceptionAsString(),
          'Exception: Invalid image dimensions.',
        );
        expect(find.byType(PageTurnAnimation), findsNothing);
        await tester.pumpAndSettle();
        expect(animated.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(animated.isNavigating, isFalse);
        expect(find.byKey(const Key('7-1')), findsOneWidget);
      });

      testWidgets('a capture that fails Flutter\'s debug paint check ends the '
          'navigation without a page turn, and is reported', (tester) async {
        final repaint = ValueNotifier(0);
        addTearDown(repaint.dispose);
        final animated = createController(animationsEnabled: true);
        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: animated,
                dayBuilder: (context, data) =>
                    CustomPaint(painter: _RepaintOn(repaint)),
              ),
            ),
          ),
        );

        // Runs after the capture frame's paint and before the capture, which
        // is scheduled after it: the pages then need painting again.
        tester.binding.addPostFrameCallback((_) => repaint.value++);
        animated.nextMonth();
        final errors = await pumpReportingErrors(tester);

        expectCaptureError(errors);
        expect(errors.single.exception, isA<AssertionError>());
        expect(find.byType(PageTurnAnimation), findsNothing);
        await tester.pumpAndSettle();
        expect(animated.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(animated.isNavigating, isFalse);
      });

      testWidgets('a swipe whose capture throws ends without moving, and the '
          'rest of its drag is ignored', (tester) async {
        final animated = createController(animationsEnabled: true);
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(devicePixelRatio: 0),
                child: page(calendar(calendarController: animated)),
              ),
            ),
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -50));
        expectCaptureError(await pumpReportingErrors(tester));
        expect(animated.isNavigating, isFalse);

        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, -15));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(animated.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(animated.isNavigating, isFalse);
      });
    });

    group('notifications that don\'t change the month', () {
      testWidgets('a bounds change redraws the days', (tester) async {
        final isEnabledByDay = <int, bool>{};

        await tester.pumpWidget(
          app(
            page(
              calendar(
                dayBuilder: (context, data) {
                  if (data.isCurrentMonth) {
                    isEnabledByDay[data.date.day] = data.isEnabled;
                  }
                  return Center(child: Text(data.date.day.toString()));
                },
              ),
            ),
          ),
        );

        expect(isEnabledByDay[11], isTrue);

        controller.setBounds(null, DateConstraint.fixed(DateTime(2024, 6, 10)));
        await tester.pump();

        expect(isEnabledByDay[10], isTrue);
        expect(isEnabledByDay[11], isFalse);
      });

      testWidgets('a new day redraws today', (tester) async {
        final todays = <DateTime>{};

        await tester.pumpWidget(
          app(
            page(
              calendar(
                dayBuilder: (context, data) {
                  if (data.isToday) todays.add(data.date);
                  return Center(child: Text(data.date.day.toString()));
                },
              ),
            ),
          ),
        );
        todays.clear();

        clock.value = DateTime(2024, 6, 13, 0, 1);
        await tester.pump();

        expect(todays, equals({DateTime(2024, 6, 13)}));
        expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
      });

      testWidgets('a notification during a navigation doesn\'t restart it', (
        tester,
      ) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(
            page(
              calendar(
                calendarController: animated,
                style: const CalendarStyle(
                  animationDuration: Duration(milliseconds: 600),
                ),
              ),
            ),
          ),
        );

        animated.goToMonth(DateTime(2024, 8, 1));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        animated.setBounds(null, DateConstraint.fixed(DateTime(2025, 1, 1)));
        // 450 ms into two turns of 300 ms: the first has ended, and after the
        // second's capture frame the second turns over the August page.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        expect(find.byKey(const Key('8-1')), findsOneWidget);

        await tester.pumpAndSettle();

        expect(animated.isNavigating, isFalse);
        expect(find.byKey(const Key('8-1')), findsOneWidget);
      });

      testWidgets('a notification after a swipe\'s release keeps the swipe', (
        tester,
      ) async {
        await tester.pumpWidget(app(page(calendar())));

        await tester.fling(
          find.byType(FlipCalendar),
          const Offset(0, -200),
          1000,
        );
        clock.value = DateTime(2024, 6, 13);
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 7, 1)));
        expect(find.byKey(const Key('7-1')), findsOneWidget);
        expect(controller.isNavigating, isFalse);
      });
    });

    group('a drag whose gesture source goes away', () {
      testWidgets('snaps back when gestures are turned off', (tester) async {
        await tester.pumpWidget(app(page(calendar())));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -50));

        await tester.pumpWidget(app(page(calendar(gesturesEnabled: false))));
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(controller.isNavigating, isFalse);

        await gesture.up();
      });

      testWidgets('snaps back when the inputs become invalid, and the next '
          'navigation runs', (tester) async {
        await tester.pumpWidget(app(page(calendar())));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -50));
        await gesture.moveBy(const Offset(0, -150));
        await tester.pump();
        expect(controller.isNavigating, isTrue);

        await tester.pumpWidget(app(page(calendar(firstDayOfWeek: 8))));
        expect(tester.takeException(), isA<RangeError>());
        await tester.pumpWidget(app(page(calendar())));
        await tester.pump();
        expect(controller.isNavigating, isFalse);

        controller.nextMonth();
        await tester.pumpAndSettle();
        expect(controller.currentMonth, equals(DateTime(2024, 7, 1)));

        await gesture.up();
      });

      testWidgets('snaps back when its pointer is cancelled', (tester) async {
        await tester.pumpWidget(app(page(calendar())));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        // 150 px: past the progress threshold.
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, -15));
        }
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(controller.isNavigating, isFalse);
      });

      testWidgets('snaps back when the calendar collapses to no height, and '
          'ignores the rest of the drag', (tester) async {
        await tester.pumpWidget(app(page(calendar())));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -15));
        await gesture.moveBy(const Offset(0, -15));
        expect(controller.isNavigating, isTrue);

        await tester.pumpWidget(
          app(SizedBox(width: 300, height: 0, child: calendar())),
        );
        await tester.pumpAndSettle();
        expect(controller.isNavigating, isFalse);

        await tester.pumpWidget(app(page(calendar())));
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, -15));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(controller.isNavigating, isFalse);
      });

      testWidgets('snaps back when the bound edge changes axis', (
        tester,
      ) async {
        await tester.pumpWidget(app(page(calendar())));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -50));

        await tester.pumpWidget(
          app(page(calendar(boundEdge: PageTurnEdge.left))),
        );
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(controller.isNavigating, isFalse);

        await gesture.up();
      });

      testWidgets('snaps back when the bound edge changes along the same '
          'axis, and ignores the rest of the drag', (tester) async {
        await tester.pumpWidget(app(page(calendar())));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -50));

        await tester.pumpWidget(
          app(page(calendar(boundEdge: PageTurnEdge.bottom))),
        );
        await tester.pumpAndSettle();
        expect(controller.isNavigating, isFalse);

        // Down is next for the bottom edge.
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(0, 15));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
        expect(controller.isNavigating, isFalse);
      });
    });

    group('validation', () {
      /// Builds a calendar with these inputs and returns the error it throws.
      Future<Object?> buildError(
        WidgetTester tester, {
        CalendarStyle style = const CalendarStyle(),
        int firstDayOfWeek = DateTime.sunday,
      }) async {
        await tester.pumpWidget(
          app(page(calendar(style: style, firstDayOfWeek: firstDayOfWeek))),
        );
        return tester.takeException();
      }

      testWidgets('rejects a firstDayOfWeek outside 1 to 7', (tester) async {
        expect(
          await buildError(tester, firstDayOfWeek: 8),
          rangeErrorWith('firstDayOfWeek', 8, start: 1, end: 7),
        );
      });

      testWidgets('rejects a style value that becomes invalid after the '
          'calendar was built', (tester) async {
        expect(await buildError(tester), isNull);

        expect(
          await buildError(
            tester,
            style: const CalendarStyle(gridLineWidth: -1),
          ),
          rangeErrorWith('style.gridLineWidth', -1.0, start: 0),
        );
      });

      testWidgets('rejects weekdayNames that are not 7 long', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(weekdayNames: ['a']),
          ),
          argumentErrorWith(
            'style.weekdayNames',
            'Must contain exactly 7 names',
            ['a'],
          ),
        );
      });

      testWidgets('rejects a flickDistanceThreshold of 0', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(flickDistanceThreshold: 0.0),
          ),
          rangeErrorWith(
            'style.flickDistanceThreshold',
            0.0,
            message: 'Must be greater than 0',
          ),
        );
      });

      testWidgets('rejects a dragBoxSizePercentage of 0', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(dragBoxSizePercentage: 0.0),
          ),
          rangeErrorWith(
            'style.dragBoxSizePercentage',
            0.0,
            message: 'Must be greater than 0',
          ),
        );
      });

      testWidgets('rejects a dragProgressThreshold above 1', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(dragProgressThreshold: 1.5),
          ),
          rangeErrorWith(
            'style.dragProgressThreshold',
            1.5,
            message: 'Must be greater than 0 and at most 1',
          ),
        );
      });

      testWidgets('rejects a dragProgressThreshold of 0', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(dragProgressThreshold: 0.0),
          ),
          rangeErrorWith(
            'style.dragProgressThreshold',
            0.0,
            message: 'Must be greater than 0 and at most 1',
          ),
        );
      });

      testWidgets('accepts a dragProgressThreshold of exactly 1', (
        tester,
      ) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(dragProgressThreshold: 1.0),
          ),
          isNull,
        );
      });

      testWidgets('rejects weekdayNames longer than 7', (tester) async {
        const names = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(weekdayNames: names),
          ),
          argumentErrorWith(
            'style.weekdayNames',
            'Must contain exactly 7 names',
            names,
          ),
        );
      });

      testWidgets('rejects a zero flickMaxDuration', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(flickMaxDuration: Duration.zero),
          ),
          argumentErrorWith(
            'style.flickMaxDuration',
            'Must be greater than zero',
            Duration.zero,
          ),
        );
      });

      testWidgets('rejects a negative animationDuration', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(
              animationDuration: Duration(milliseconds: -1),
            ),
          ),
          argumentErrorWith(
            'style.animationDuration',
            'Must not be negative',
            const Duration(milliseconds: -1),
          ),
        );
      });

      testWidgets('rejects a negative gridLineWidth', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(gridLineWidth: -1.0),
          ),
          rangeErrorWith('style.gridLineWidth', -1.0, start: 0),
        );
      });

      testWidgets('rejects a negative weekdayHeaderHeight', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(weekdayHeaderHeight: -1.0),
          ),
          rangeErrorWith('style.weekdayHeaderHeight', -1.0, start: 0),
        );
      });

      testWidgets('rejects a negative todayBorderWidth', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(todayBorderWidth: -1.0),
          ),
          rangeErrorWith('style.todayBorderWidth', -1.0, start: 0),
        );
      });

      testWidgets('rejects a NaN gridLineWidth', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(gridLineWidth: double.nan),
          ),
          rangeErrorWith('style.gridLineWidth', isNaN, start: 0),
        );
      });

      testWidgets('rejects a negative dayTextSize', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(dayTextSize: -1.0),
          ),
          rangeErrorWith('style.dayTextSize', -1.0, start: 0),
        );
      });

      testWidgets('rejects a padding with a negative side', (tester) async {
        for (final padding in const [
          EdgeInsets.only(left: -1),
          EdgeInsets.only(top: -1),
          EdgeInsets.only(right: -1),
          EdgeInsets.only(bottom: -1),
        ]) {
          expect(
            await buildError(tester, style: CalendarStyle(padding: padding)),
            argumentErrorWith(
              'style.padding',
              'Must be finite and not negative',
              padding,
            ),
          );
        }
      });

      testWidgets('rejects a todayMargin with an infinite side', (
        tester,
      ) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(
              todayMargin: EdgeInsets.only(bottom: double.infinity),
            ),
          ),
          argumentErrorWith(
            'style.todayMargin',
            'Must be finite and not negative',
            const EdgeInsets.only(bottom: double.infinity),
          ),
        );
      });

      testWidgets('rejects a borderRadius with a negative radius', (
        tester,
      ) async {
        const negative = Radius.circular(-1);
        for (final borderRadius in const [
          BorderRadius.only(topLeft: negative),
          BorderRadius.only(topRight: negative),
          BorderRadius.only(bottomLeft: negative),
          BorderRadius.only(bottomRight: negative),
          BorderRadius.only(topLeft: Radius.elliptical(0, -1)),
        ]) {
          expect(
            await buildError(
              tester,
              style: CalendarStyle(borderRadius: borderRadius),
            ),
            argumentErrorWith(
              'style.borderRadius',
              'Must be finite and not negative',
              borderRadius,
            ),
          );
        }
      });

      testWidgets('rejects a todayBorderRadius with an infinite radius', (
        tester,
      ) async {
        for (final todayBorderRadius in const [
          BorderRadius.only(topLeft: Radius.elliptical(double.infinity, 0)),
          BorderRadius.only(topLeft: Radius.elliptical(0, double.infinity)),
        ]) {
          expect(
            await buildError(
              tester,
              style: CalendarStyle(todayBorderRadius: todayBorderRadius),
            ),
            argumentErrorWith(
              'style.todayBorderRadius',
              'Must be finite and not negative',
              todayBorderRadius,
            ),
          );
        }
      });

      Matcher mustBeFinite(String name) {
        return rangeErrorWith(name, double.infinity, message: 'Must be finite');
      }

      testWidgets('rejects an infinite gridLineWidth', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(gridLineWidth: double.infinity),
          ),
          mustBeFinite('style.gridLineWidth'),
        );
      });

      testWidgets('rejects an infinite weekdayHeaderHeight', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(weekdayHeaderHeight: double.infinity),
          ),
          mustBeFinite('style.weekdayHeaderHeight'),
        );
      });

      testWidgets('rejects an infinite todayBorderWidth', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(todayBorderWidth: double.infinity),
          ),
          mustBeFinite('style.todayBorderWidth'),
        );
      });

      testWidgets('rejects an infinite flickDistanceThreshold', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(flickDistanceThreshold: double.infinity),
          ),
          mustBeFinite('style.flickDistanceThreshold'),
        );
      });

      testWidgets('rejects an infinite dragBoxSizePercentage', (tester) async {
        expect(
          await buildError(
            tester,
            style: const CalendarStyle(dragBoxSizePercentage: double.infinity),
          ),
          mustBeFinite('style.dragBoxSizePercentage'),
        );
      });

      testWidgets('an invalid input does not strand a navigation', (
        tester,
      ) async {
        final animated = createController(animationsEnabled: true);

        await tester.pumpWidget(
          app(page(calendar(calendarController: animated, firstDayOfWeek: 8))),
        );

        expect(tester.takeException(), isA<RangeError>());

        animated.goToMonth(DateTime(2024, 7, 1));
        await tester.pump();

        expect(tester.takeException(), isA<RangeError>());
        expect(animated.isNavigating, isFalse);

        await tester.pump();

        expect(tester.takeException(), isA<RangeError>());
        expect(animated.isNavigating, isFalse);
      });
    });
  });
}

/// Counts the on-screen reports its calendars make.
class _CountingController extends CalendarController {
  _CountingController({super.initialMonth, super.clock});

  int onScreenReports = 0;

  @override
  void calendarOnScreen() {
    onScreenReports++;
    super.calendarOnScreen();
  }
}

/// Paints nothing, and paints again whenever the listenable it is given
/// notifies.
class _RepaintOn extends CustomPainter {
  _RepaintOn(Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(_RepaintOn oldDelegate) => false;
}
