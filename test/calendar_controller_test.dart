import 'package:flip_calendar/flip_calendar.dart';
import 'package:flip_calendar/src/calendar/calendar_controller.dart'
    show ControlledCalendar;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'error_matchers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarController', () {
    late ValueNotifier<DateTime> clock;

    setUp(() {
      clock = ValueNotifier(DateTime(2026, 9, 28, 10, 41));
    });

    tearDown(() {
      clock.dispose();
    });

    CalendarController createController({
      DateTime? initialMonth,
      DateConstraint? minDate,
      DateConstraint? maxDate,
      bool animationsEnabled = true,
      int maxAnimatedMonthJump = 6,
      MultiMonthAnimationMode multiMonthAnimationMode =
          MultiMonthAnimationMode.sequential,
    }) {
      final controller = CalendarController(
        initialMonth: initialMonth,
        clock: clock,
        minDate: minDate,
        maxDate: maxDate,
        animationsEnabled: animationsEnabled,
        maxAnimatedMonthJump: maxAnimatedMonthJump,
        multiMonthAnimationMode: multiMonthAnimationMode,
      );
      addTearDown(controller.dispose);
      return controller;
    }

    final june = DateTime(2024, 6, 1);
    final july = DateTime(2024, 7, 1);
    final august = DateTime(2024, 8, 1);

    // Two clock readings years apart. The device clock can match at most
    // one, so a test that checks both fails if the controller reads the
    // device clock instead of the clock it was given.
    final readings = [
      DateTime(2026, 9, 28, 10, 41),
      DateTime(2031, 3, 15, 10, 41),
    ];

    group('construction', () {
      test('defaults to the clock\'s month', () {
        for (final reading in readings) {
          clock.value = reading;
          final controller = createController();
          expect(
            controller.currentMonth,
            equals(DateTime(reading.year, reading.month, 1)),
          );
        }
      });

      test('reads today once, for the starting month and the day', () {
        final clock = _ScriptedClock(DateTime(2026, 9, 1));
        // The first read is the last moment of September 30, every later
        // read October 1.
        clock.script(
          DateTime(2026, 9, 30, 23, 59, 59, 999),
          DateTime(2026, 10, 1),
        );
        final controller = CalendarController(clock: clock);
        addTearDown(controller.dispose);

        expect(clock.scriptedReads, equals(1));
        expect(controller.currentMonth, equals(DateTime(2026, 9, 1)));
      });

      test('normalizes the initial month to its first day', () {
        final controller = createController(
          initialMonth: DateTime(2024, 3, 25, 14, 30),
        );
        expect(controller.currentMonth, equals(DateTime(2024, 3, 1)));
      });

      test('throws when the bounds are crossed', () {
        final minDate = DateConstraint.fixed(DateTime(2026, 10, 1));
        expect(
          () => CalendarController(
            initialMonth: DateTime(2026, 9, 1),
            clock: clock,
            minDate: minDate,
            maxDate: DateConstraint.fixed(DateTime(2026, 9, 30)),
          ),
          throwsA(argumentErrorWith('minDate', 'Is after maxDate', minDate)),
        );
      });

      test('throws when the initial month has no allowed day', () {
        expect(
          () => CalendarController(
            initialMonth: DateTime(2026, 9, 1),
            clock: clock,
            maxDate: DateConstraint.fixed(DateTime(2026, 8, 31)),
          ),
          throwsA(
            argumentErrorWith(
              'initialMonth',
              'Has no allowed day',
              DateTime(2026, 9, 1),
            ),
          ),
        );
      });

      test('throws when today\'s month has no allowed day', () {
        for (final reading in readings) {
          clock.value = reading;
          final nextMonth = DateTime(reading.year, reading.month + 1, 1);
          expect(
            () => CalendarController(
              clock: clock,
              minDate: DateConstraint.fixed(nextMonth),
            ),
            throwsA(
              argumentErrorWith(
                'initialMonth',
                'Has no allowed day',
                DateTime(reading.year, reading.month, 1),
              ),
            ),
          );
        }
      });

      test('throws for a negative maxAnimatedMonthJump', () {
        expect(
          () => CalendarController(clock: clock, maxAnimatedMonthJump: -1),
          throwsA(rangeErrorWith('maxAnimatedMonthJump', -1, start: 0)),
        );
      });
    });

    group('today', () {
      test('is the clock\'s day', () {
        final controller = createController();
        for (final reading in readings) {
          clock.value = reading;
          expect(
            controller.today,
            equals(DateTime(reading.year, reading.month, reading.day)),
          );
        }
      });

      test('a tick on the same day notifies nothing', () {
        final controller = createController();
        var notifications = 0;
        controller.addListener(() => notifications++);

        clock.value = DateTime(2026, 9, 28, 23, 59);

        expect(notifications, equals(0));
      });

      test('a new day notifies once', () {
        final controller = createController();
        var notifications = 0;
        controller.addListener(() => notifications++);

        clock.value = DateTime(2026, 9, 29, 0, 1);
        clock.value = DateTime(2026, 9, 29, 0, 2);

        expect(notifications, equals(1));
        expect(controller.today, equals(DateTime(2026, 9, 29)));
      });

      test('without a clock is the device\'s day', () {
        final controller = CalendarController();
        addTearDown(controller.dispose);
        // Read on both sides, in case the day changes between the reads.
        final before = DateTime.now();
        final today = controller.today;
        final after = DateTime.now();

        expect(
          today,
          anyOf(
            DateTime(before.year, before.month, before.day),
            DateTime(after.year, after.month, after.day),
          ),
        );
        expect(
          controller.currentMonth,
          anyOf(
            DateTime(before.year, before.month, 1),
            DateTime(after.year, after.month, 1),
          ),
        );
      });

      test('a new day does not move the month', () {
        final controller = createController();

        clock.value = DateTime(2026, 10, 1);

        expect(controller.currentMonth, equals(DateTime(2026, 9, 1)));
      });
    });

    group('questions', () {
      CalendarController createBounded() {
        return createController(
          initialMonth: DateTime(2026, 9, 1),
          minDate: DateConstraint.fixed(DateTime(2026, 9, 10)),
          maxDate: DateConstraint.fixed(DateTime(2026, 9, 20)),
        );
      }

      test('isDateAllowed includes both ends and ignores the time', () {
        final controller = createBounded();
        expect(controller.isDateAllowed(DateTime(2026, 9, 10, 23, 59)), isTrue);
        expect(controller.isDateAllowed(DateTime(2026, 9, 20, 23, 59)), isTrue);
        expect(controller.isDateAllowed(DateTime(2026, 9, 9)), isFalse);
        expect(controller.isDateAllowed(DateTime(2026, 9, 21)), isFalse);
      });

      test('canGoTo is true for a month with an allowed day', () {
        final controller = createBounded();
        expect(controller.canGoTo(DateTime(2026, 9, 1)), isTrue);
        // A day past the bound, in a month with allowed days.
        expect(controller.canGoTo(DateTime(2026, 9, 25)), isTrue);
        expect(controller.canGoTo(DateTime(2026, 8, 31)), isFalse);
      });

      test('canGoTo is true for a month whose last day is the lower bound', () {
        final controller = createController(
          initialMonth: DateTime(2026, 9, 1),
          minDate: DateConstraint.fixed(DateTime(2026, 8, 31)),
        );
        expect(controller.canGoTo(DateTime(2026, 8, 1)), isTrue);
        expect(controller.canGoTo(DateTime(2026, 7, 1)), isFalse);
      });

      test('first and last allowed months are the months of the bounds', () {
        final controller = createBounded();
        expect(controller.firstAllowedMonth, equals(DateTime(2026, 9, 1)));
        expect(controller.lastAllowedMonth, equals(DateTime(2026, 9, 1)));
      });

      test('first and last allowed months are null without bounds', () {
        final controller = createController();
        expect(controller.firstAllowedMonth, isNull);
        expect(controller.lastAllowedMonth, isNull);
      });

      test('relative bounds resolve against today, each to its own month', () {
        // Today is September 28, 2026: the bounds are July 28 and
        // December 28.
        final controller = createController(
          minDate: DateConstraint.relative(months: -2),
          maxDate: DateConstraint.relative(months: 3),
        );
        expect(controller.firstAllowedMonth, equals(DateTime(2026, 7, 1)));
        expect(controller.lastAllowedMonth, equals(DateTime(2026, 12, 1)));
        expect(controller.isDateAllowed(DateTime(2026, 7, 28)), isTrue);
        expect(controller.isDateAllowed(DateTime(2026, 7, 27)), isFalse);
        expect(controller.isDateAllowed(DateTime(2026, 12, 28)), isTrue);
        expect(controller.isDateAllowed(DateTime(2026, 12, 29)), isFalse);
      });
    });

    group('setBounds', () {
      test('throws for crossed bounds and keeps the old ones', () {
        final minDate = DateConstraint.fixed(DateTime(2026, 9, 1));
        final controller = createController(minDate: minDate);

        final crossedMin = DateConstraint.fixed(DateTime(2026, 10, 1));
        expect(
          () => controller.setBounds(
            crossedMin,
            DateConstraint.fixed(DateTime(2026, 9, 30)),
          ),
          throwsA(argumentErrorWith('minDate', 'Is after maxDate', crossedMin)),
        );
        expect(controller.minDate, equals(minDate));
        expect(controller.maxDate, isNull);
      });

      test('notifies once when a bound changes', () {
        final controller = createController();
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.setBounds(null, DateConstraint.relative(months: 1));

        expect(notifications, equals(1));
        expect(controller.maxDate, equals(DateConstraint.relative(months: 1)));
      });

      test('does not notify for bounds equal by value', () {
        final controller = createController(
          maxDate: DateConstraint.relative(months: 1),
        );
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.setBounds(null, DateConstraint.relative(months: 1));

        expect(notifications, equals(0));
      });

      test('stores and notifies a new lower bound alone', () {
        final controller = createController();
        var notifications = 0;
        controller.addListener(() => notifications++);
        final minDate = DateConstraint.fixed(DateTime(2026, 9, 1));

        controller.setBounds(minDate, null);

        expect(controller.minDate, equals(minDate));
        expect(notifications, equals(1));
      });

      test('replaces a bound with a different one of the same kind', () {
        final controller = createController(
          maxDate: DateConstraint.fixed(DateTime(2026, 9, 30)),
        );
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.setBounds(
          null,
          DateConstraint.fixed(DateTime(2026, 10, 31)),
        );
        controller.setBounds(null, DateConstraint.relative(months: 1));
        controller.setBounds(null, DateConstraint.relative(months: 2));

        expect(controller.maxDate, equals(DateConstraint.relative(months: 2)));
        expect(notifications, equals(3));
      });

      test('accepts equal bounds, one allowed day', () {
        final controller = createController();
        final day = DateConstraint.fixed(DateTime(2026, 9, 20));

        controller.setBounds(day, day);

        expect(controller.canGoTo(DateTime(2026, 9, 1)), isTrue);
      });

      test('checks bounds that have crossed since they were set', () {
        final controller = createController();
        final minDate = DateConstraint.fixed(DateTime(2026, 9, 25));
        controller.setBounds(minDate, DateConstraint.today());
        clock.value = DateTime(2026, 9, 10);

        expect(
          () => controller.setBounds(minDate, DateConstraint.today()),
          throwsA(argumentErrorWith('minDate', 'Is after maxDate', minDate)),
        );
      });

      test('checks crossing against the clock\'s today', () {
        final controller = createController();
        for (final reading in readings) {
          clock.value = reading;
          final today = DateTime(reading.year, reading.month, reading.day);
          final yesterday = DateConstraint.fixed(
            today.subtract(const Duration(days: 1)),
          );
          final tomorrow = DateConstraint.fixed(
            today.add(const Duration(days: 1)),
          );

          controller.setBounds(yesterday, DateConstraint.today());
          expect(
            () => controller.setBounds(tomorrow, DateConstraint.today()),
            throwsA(argumentErrorWith('minDate', 'Is after maxDate', tomorrow)),
          );
        }
      });

      test('does not move a month that becomes forbidden', () {
        final controller = createController();

        controller.setBounds(null, DateConstraint.fixed(DateTime(2026, 8, 31)));

        expect(controller.currentMonth, equals(DateTime(2026, 9, 1)));
        expect(controller.canGoTo(controller.currentMonth), isFalse);
      });
    });

    group('settings', () {
      test('animationsEnabled notifies only on a change', () {
        final controller = createController();
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.animationsEnabled = true;
        expect(notifications, equals(0));
        controller.animationsEnabled = false;
        expect(notifications, equals(1));
        expect(controller.animationsEnabled, isFalse);
      });

      test('maxAnimatedMonthJump notifies only on a change', () {
        final controller = createController();
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.maxAnimatedMonthJump = 6;
        expect(notifications, equals(0));
        controller.maxAnimatedMonthJump = 2;
        expect(notifications, equals(1));
        expect(controller.maxAnimatedMonthJump, equals(2));
      });

      test('multiMonthAnimationMode notifies only on a change', () {
        final controller = createController();
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.multiMonthAnimationMode = MultiMonthAnimationMode.sequential;
        expect(notifications, equals(0));
        controller.multiMonthAnimationMode = MultiMonthAnimationMode.directJump;
        expect(notifications, equals(1));
        expect(
          controller.multiMonthAnimationMode,
          equals(MultiMonthAnimationMode.directJump),
        );
      });

      test('a maxAnimatedMonthJump of 0 is accepted, and no sequential '
          'navigation animates', () {
        final controller = createController(
          initialMonth: june,
          maxAnimatedMonthJump: 0,
        );
        expect(controller.monthsOnWayTo(july), equals([july]));

        controller.maxAnimatedMonthJump = 1;
        controller.maxAnimatedMonthJump = 0;

        expect(controller.maxAnimatedMonthJump, equals(0));
      });

      test('a negative maxAnimatedMonthJump throws and keeps the value', () {
        final controller = createController();

        expect(
          () => controller.maxAnimatedMonthJump = -1,
          throwsA(rangeErrorWith('maxAnimatedMonthJump', -1, start: 0)),
        );
        expect(controller.maxAnimatedMonthJump, equals(6));
      });
    });

    group('monthsOnWayTo', () {
      test('is empty when nothing would move', () {
        final controller = createController(initialMonth: june);
        expect(controller.monthsOnWayTo(DateTime(2024, 6, 20)), isEmpty);
      });

      test('with animations off is the landing month alone', () {
        final controller = createController(
          initialMonth: june,
          animationsEnabled: false,
        );
        expect(
          controller.monthsOnWayTo(DateTime(2024, 9, 1)),
          equals([DateTime(2024, 9, 1)]),
        );
      });

      test('in direct-jump mode is the current and landing months', () {
        final controller = createController(
          initialMonth: june,
          multiMonthAnimationMode: MultiMonthAnimationMode.directJump,
        );
        expect(
          controller.monthsOnWayTo(DateTime(2024, 9, 1)),
          equals([june, DateTime(2024, 9, 1)]),
        );
      });

      test('in direct-jump mode ignores maxAnimatedMonthJump', () {
        final controller = createController(
          initialMonth: june,
          maxAnimatedMonthJump: 0,
          multiMonthAnimationMode: MultiMonthAnimationMode.directJump,
        );
        expect(controller.monthsOnWayTo(july), equals([june, july]));
        expect(
          controller.monthsOnWayTo(DateTime(2024, 9, 1)),
          equals([june, DateTime(2024, 9, 1)]),
        );
      });

      test('in sequential mode is every month on the way', () {
        final controller = createController(initialMonth: june);
        expect(
          controller.monthsOnWayTo(DateTime(2024, 9, 1)),
          equals([
            june,
            DateTime(2024, 7, 1),
            DateTime(2024, 8, 1),
            DateTime(2024, 9, 1),
          ]),
        );
      });

      test('in sequential mode beyond the maximum is the landing month', () {
        final controller = createController(
          initialMonth: june,
          maxAnimatedMonthJump: 2,
        );
        expect(
          controller.monthsOnWayTo(DateTime(2024, 9, 1)),
          equals([DateTime(2024, 9, 1)]),
        );
      });

      test('in sequential mode backward is every month on the way', () {
        final controller = createController(initialMonth: june);
        expect(
          controller.monthsOnWayTo(DateTime(2024, 4, 1)),
          equals([june, DateTime(2024, 5, 1), DateTime(2024, 4, 1)]),
        );
      });

      test('in sequential mode at the maximum is every month on the way', () {
        final controller = createController(
          initialMonth: june,
          maxAnimatedMonthJump: 3,
        );
        expect(
          controller.monthsOnWayTo(DateTime(2024, 9, 1)),
          equals([june, july, august, DateTime(2024, 9, 1)]),
        );
      });

      test('in sequential mode crosses into the next year', () {
        final controller = createController(
          initialMonth: DateTime(2024, 11, 1),
        );
        expect(
          controller.monthsOnWayTo(DateTime(2025, 2, 1)),
          equals([
            DateTime(2024, 11, 1),
            DateTime(2024, 12, 1),
            DateTime(2025, 1, 1),
            DateTime(2025, 2, 1),
          ]),
        );
      });

      test('ends on the landing month when the target is not allowed', () {
        final controller = createController(
          initialMonth: august,
          maxDate: DateConstraint.fixed(DateTime(2024, 9, 30)),
        );
        expect(
          controller.monthsOnWayTo(DateTime(2024, 11, 1)),
          equals([august, DateTime(2024, 9, 1)]),
        );
      });
    });

    group('notifications during a build', () {
      testWidgets('a change in a build is announced after the frame', (
        tester,
      ) async {
        final controller = createController();
        final phases = <SchedulerPhase>[];
        controller.addListener(
          () => phases.add(SchedulerBinding.instance.schedulerPhase),
        );
        var notifiedDuringBuild = -1;

        await tester.pumpWidget(
          Builder(
            builder: (context) {
              controller.animationsEnabled = false;
              notifiedDuringBuild = phases.length;
              return const SizedBox();
            },
          ),
        );

        expect(notifiedDuringBuild, equals(0));
        expect(phases, equals([SchedulerPhase.postFrameCallbacks]));
      });

      testWidgets('two changes in a build give one notification', (
        tester,
      ) async {
        final controller = createController();
        var notifications = 0;
        controller.addListener(() => notifications++);

        await tester.pumpWidget(
          Builder(
            builder: (context) {
              controller.setBounds(
                null,
                DateConstraint.fixed(DateTime(2026, 12, 31)),
              );
              controller.animationsEnabled = false;
              return const SizedBox();
            },
          ),
        );

        expect(notifications, equals(1));
      });

      testWidgets('a change in a later frame is announced after that frame', (
        tester,
      ) async {
        final controller = createController();
        var notifications = 0;
        controller.addListener(() => notifications++);

        await tester.pumpWidget(
          Builder(
            builder: (context) {
              controller.animationsEnabled = false;
              return const SizedBox();
            },
          ),
        );
        await tester.pumpWidget(
          Builder(
            builder: (context) {
              controller.animationsEnabled = true;
              return const SizedBox(width: 1);
            },
          ),
        );

        expect(notifications, equals(2));
      });

      testWidgets('changes during layout and paint are announced after the '
          'frame', (tester) async {
        final controller = createController();
        final phases = <SchedulerPhase>[];
        controller.addListener(
          () => phases.add(SchedulerBinding.instance.schedulerPhase),
        );

        await tester.pumpWidget(
          Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  controller.animationsEnabled = false;
                  return const SizedBox();
                },
              ),
            ],
          ),
        );
        await tester.pumpWidget(
          CustomPaint(
            painter: _Painter(() => controller.animationsEnabled = true),
          ),
        );

        expect(
          phases,
          equals([
            SchedulerPhase.postFrameCallbacks,
            SchedulerPhase.postFrameCallbacks,
          ]),
        );
      });

      testWidgets('a calendar leaving during a build is announced after the '
          'frame', (tester) async {
        final controller = createController(initialMonth: june);
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);
        controller.goToMonth(august);
        final phases = <SchedulerPhase>[];
        controller.addListener(
          () => phases.add(SchedulerBinding.instance.schedulerPhase),
        );

        await tester.pumpWidget(
          Builder(
            builder: (context) {
              controller.calendarLeft(calendar);
              return const SizedBox();
            },
          ),
        );

        expect(phases, equals([SchedulerPhase.postFrameCallbacks]));
      });
    });

    group('navigation without a calendar', () {
      test('goToMonth sets the month at once and notifies once', () {
        final controller = createController(initialMonth: DateTime(2024, 1, 1));
        var notifications = 0;
        controller.addListener(() => notifications++);

        // Beyond the 6-month jump limit, so the only page recorded is the
        // landing month itself, normalized from the request.
        controller.goToMonth(DateTime(2025, 6, 15, 10));

        expect(controller.currentMonth, equals(DateTime(2025, 6, 1)));
        expect(notifications, equals(1));
      });

      test('goToMonth to the same month does nothing', () {
        final controller = createController(initialMonth: DateTime(2024, 6, 1));
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.goToMonth(DateTime(2024, 6, 15));

        expect(notifications, equals(0));
      });

      test('nextMonth goes to the following month', () {
        final controller = createController(initialMonth: DateTime(2024, 6, 1));
        controller.nextMonth();
        expect(controller.currentMonth, equals(DateTime(2024, 7, 1)));
      });

      test('nextMonth from December goes to January of the next year', () {
        final controller = createController(
          initialMonth: DateTime(2024, 12, 1),
        );
        controller.nextMonth();
        expect(controller.currentMonth, equals(DateTime(2025, 1, 1)));
      });

      test('previousMonth goes to the month before', () {
        final controller = createController(initialMonth: DateTime(2024, 6, 1));
        controller.previousMonth();
        expect(controller.currentMonth, equals(DateTime(2024, 5, 1)));
      });

      test(
        'previousMonth from January goes to December of the year before',
        () {
          final controller = createController(
            initialMonth: DateTime(2024, 1, 1),
          );
          controller.previousMonth();
          expect(controller.currentMonth, equals(DateTime(2023, 12, 1)));
        },
      );

      test('goToToday goes to the clock\'s month', () {
        final controller = createController(initialMonth: DateTime(2020, 1, 1));
        for (final reading in readings) {
          clock.value = reading;
          controller.goToToday();
          expect(
            controller.currentMonth,
            equals(DateTime(reading.year, reading.month, 1)),
          );
        }
      });

      test('goToToday reads today once, for its target and its bounds', () {
        final october = DateTime(2026, 10, 1);
        final clock = _ScriptedClock(DateTime(2026, 10, 15, 12));
        final controller = CalendarController(
          initialMonth: october,
          clock: clock,
        );
        addTearDown(controller.dispose);
        controller.setBounds(null, DateConstraint.relative(months: -1));
        // The first read is the last moment of September 30, every later
        // read October 1. Read once, today is September 30: September is
        // past the bound (August 30), so the request lands on August.
        clock.script(
          DateTime(2026, 9, 30, 23, 59, 59, 999),
          DateTime(2026, 10, 1),
        );

        controller.goToToday();

        expect(controller.currentMonth, equals(DateTime(2026, 8, 1)));
        expect(clock.scriptedReads, equals(1));
      });

      test('goToYearMonth goes to that year and month', () {
        final controller = createController(initialMonth: DateTime(2024, 1, 1));
        controller.goToYearMonth(2025, 8);
        expect(controller.currentMonth, equals(DateTime(2025, 8, 1)));
      });

      test('goToYearMonth throws for a month outside 1 to 12', () {
        final controller = createController(initialMonth: DateTime(2024, 1, 1));
        for (final month in [0, 13]) {
          expect(
            () => controller.goToYearMonth(2026, month),
            throwsA(
              isA<RangeError>()
                  .having((error) => error.name, 'name', 'month')
                  .having((error) => error.start, 'start', 1)
                  .having((error) => error.end, 'end', 12),
            ),
          );
        }
        expect(controller.currentMonth, equals(DateTime(2024, 1, 1)));
      });

      test('goToYearMonth throws for a year DateTime cannot hold', () {
        final controller = createController(initialMonth: DateTime(2024, 1, 1));
        expect(
          () => controller.goToYearMonth(300000, 1),
          throwsA(
            isA<RangeError>()
                .having((error) => error.name, 'name', 'year')
                .having(
                  (error) => error.message,
                  'message',
                  'Outside the dates DateTime supports',
                ),
          ),
        );
        expect(controller.currentMonth, equals(DateTime(2024, 1, 1)));
      });

      test('is never busy, and whenAtRest completes', () async {
        final controller = createController();

        controller.goToMonth(DateTime(2026, 11, 1));

        expect(controller.isNavigating, isFalse);
        var atRest = false;
        controller.whenAtRest().then((_) => atRest = true);
        await Future<void>.delayed(Duration.zero);
        expect(atRest, isTrue);
      });
    });

    group('landing', () {
      final lastAllowed = DateConstraint.fixed(DateTime(2026, 9, 30));

      test('from the last allowed month, next moves nothing', () {
        final controller = createController(
          initialMonth: DateTime(2026, 9, 1),
          maxDate: lastAllowed,
        );
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.nextMonth();

        expect(controller.currentMonth, equals(DateTime(2026, 9, 1)));
        expect(notifications, equals(0));
      });

      test('a request past the bound lands on the last allowed month', () {
        final controller = createController(
          initialMonth: DateTime(2026, 8, 1),
          maxDate: lastAllowed,
        );

        controller.goToMonth(DateTime(2026, 11, 1));

        expect(controller.currentMonth, equals(DateTime(2026, 9, 1)));
      });

      test('previous from a forbidden month lands on the last allowed '
          'month', () {
        final controller = createController(
          initialMonth: DateTime(2026, 12, 1),
        );
        controller.setBounds(null, lastAllowed);

        controller.previousMonth();

        expect(controller.currentMonth, equals(DateTime(2026, 9, 1)));
      });

      test('next from a forbidden month moves nothing', () {
        final controller = createController(
          initialMonth: DateTime(2026, 12, 1),
        );
        controller.setBounds(null, lastAllowed);

        controller.nextMonth();

        expect(controller.currentMonth, equals(DateTime(2026, 12, 1)));
      });

      test('a request before the lower bound lands on its month', () {
        final controller = createController(
          initialMonth: DateTime(2026, 6, 1),
          minDate: DateConstraint.fixed(DateTime(2026, 3, 15)),
        );

        controller.goToMonth(DateTime(2026, 1, 1));

        expect(controller.currentMonth, equals(DateTime(2026, 3, 1)));
      });

      test('bounds that cross inside one month allow no month', () {
        clock.value = DateTime(2026, 9, 25);
        final controller = createController(
          minDate: DateConstraint.fixed(DateTime(2026, 9, 20)),
          maxDate: DateConstraint.today(),
        );
        var notifications = 0;
        controller.addListener(() => notifications++);

        clock.value = DateTime(2026, 9, 15);

        expect(notifications, equals(1));
        expect(controller.canGoTo(DateTime(2026, 9, 1)), isFalse);
        expect(controller.firstAllowedMonth, equals(DateTime(2026, 9, 1)));
        expect(controller.lastAllowedMonth, equals(DateTime(2026, 9, 1)));
        controller.goToMonth(DateTime(2026, 10, 1));
        controller.goToMonth(DateTime(2026, 8, 1));
        expect(controller.currentMonth, equals(DateTime(2026, 9, 1)));
      });

      test('bounds that cross across two months allow no month', () {
        clock.value = DateTime(2026, 10, 10);
        final controller = createController(initialMonth: august);
        controller.setBounds(
          DateConstraint.fixed(DateTime(2026, 10, 5)),
          DateConstraint.today(),
        );
        // Today moves back: the upper bound, September 10, is now a month
        // before the lower bound, October 5.
        clock.value = DateTime(2026, 9, 10);

        controller.goToMonth(DateTime(2026, 11, 1));

        expect(controller.currentMonth, equals(august));
        expect(controller.canGoTo(DateTime(2026, 9, 1)), isFalse);
      });

      test('a request lands on the allowed month nearest the target, not '
          'the current month', () {
        final controller = createController(
          initialMonth: DateTime(2027, 12, 1),
        );
        controller.setBounds(
          DateConstraint.fixed(DateTime(2026, 3, 15)),
          DateConstraint.fixed(DateTime(2026, 9, 20)),
        );

        // From forbidden December 2027 back to January 2026: March 2026 is
        // nearest the target, September 2026 nearest the current month.
        controller.goToMonth(DateTime(2026, 1, 1));

        expect(controller.currentMonth, equals(DateTime(2026, 3, 1)));
      });

      test('from a month before the lower bound, next lands on its month', () {
        final controller = createController(initialMonth: DateTime(2026, 1, 1));
        controller.setBounds(DateConstraint.fixed(DateTime(2026, 3, 15)), null);

        controller.nextMonth();

        expect(controller.currentMonth, equals(DateTime(2026, 3, 1)));
      });

      test('from a month before the lower bound, previous moves nothing', () {
        final controller = createController(initialMonth: DateTime(2026, 1, 1));
        controller.setBounds(DateConstraint.fixed(DateTime(2026, 3, 15)), null);

        controller.previousMonth();

        expect(controller.currentMonth, equals(DateTime(2026, 1, 1)));
      });
    });

    group('busy and calendars', () {
      test('an accepted navigation with a calendar is busy at once', () {
        final controller = createController(initialMonth: june);
        controller.calendarJoined(_TestCalendar());
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.goToMonth(august);

        expect(controller.isNavigating, isTrue);
        expect(
          controller.calendarPages,
          equals([june, DateTime(2024, 7, 1), august]),
        );
        expect(notifications, equals(1));
      });

      test('a request while busy is ignored', () {
        final controller = createController(initialMonth: june);
        controller.calendarJoined(_TestCalendar());
        controller.goToMonth(august);
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.goToMonth(DateTime(2024, 10, 1));

        expect(controller.currentMonth, equals(august));
        expect(notifications, equals(0));
      });

      test('the calendar\'s report ends the navigation', () async {
        final controller = createController(initialMonth: june);
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);
        controller.goToMonth(august);
        var atRest = false;
        controller.whenAtRest().then((_) => atRest = true);
        var notifications = 0;
        controller.addListener(() => notifications++);

        await Future<void>.delayed(Duration.zero);
        expect(atRest, isFalse);

        controller.calendarDone(calendar);
        await Future<void>.delayed(Duration.zero);

        expect(controller.isNavigating, isFalse);
        expect(controller.calendarPages, isEmpty);
        expect(notifications, equals(1));
        expect(atRest, isTrue);
      });

      test('every calendar joined at the start must report', () {
        final controller = createController(initialMonth: june);
        final first = _TestCalendar();
        final second = _TestCalendar();
        final joinedLate = _TestCalendar();
        controller.calendarJoined(first);
        controller.calendarJoined(second);
        controller.goToMonth(august);
        controller.calendarJoined(joinedLate);

        controller.calendarDone(first);
        expect(controller.isNavigating, isTrue);
        controller.calendarDone(second);
        expect(controller.isNavigating, isFalse);
      });

      test('the only calendar that owes leaving ends the navigation', () {
        final controller = createController(initialMonth: june);
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);
        controller.goToMonth(august);
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.calendarLeft(calendar);

        expect(controller.isNavigating, isFalse);
        expect(notifications, equals(1));
      });

      test('a calendar that owes leaving while another owes keeps the '
          'navigation', () async {
        final controller = createController(initialMonth: june);
        final leaving = _TestCalendar();
        final staying = _TestCalendar();
        controller.calendarJoined(leaving);
        controller.calendarJoined(staying);
        controller.goToMonth(august);
        var atRest = false;
        controller.whenAtRest().then((_) => atRest = true);

        controller.calendarLeft(leaving);
        await Future<void>.delayed(Duration.zero);

        expect(controller.isNavigating, isTrue);
        expect(controller.calendarPages, equals([june, july, august]));
        expect(atRest, isFalse);

        controller.calendarDone(staying);
        await Future<void>.delayed(Duration.zero);

        expect(controller.isNavigating, isFalse);
        expect(atRest, isTrue);
      });

      test('every whenAtRest caller completes', () async {
        final controller = createController(initialMonth: june);
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);
        controller.goToMonth(august);
        var first = false;
        var second = false;
        controller.whenAtRest().then((_) => first = true);
        controller.whenAtRest().then((_) => second = true);

        controller.calendarDone(calendar);
        await Future<void>.delayed(Duration.zero);

        expect(first, isTrue);
        expect(second, isTrue);
      });

      test('a navigation with no calendar records no pages', () {
        final controller = createController(initialMonth: june);

        controller.goToMonth(august);

        expect(controller.calendarPages, isEmpty);
      });

      test(
        'settings changed during a navigation leave its pages unchanged',
        () {
          final controller = createController(initialMonth: june);
          controller.calendarJoined(_TestCalendar());
          controller.goToMonth(august);

          controller.animationsEnabled = false;
          controller.maxAnimatedMonthJump = 0;
          controller.multiMonthAnimationMode =
              MultiMonthAnimationMode.directJump;

          expect(
            controller.calendarPages,
            equals([june, DateTime(2024, 7, 1), august]),
          );
        },
      );

      test('monthsOnWayTo is empty while busy', () {
        final controller = createController(initialMonth: june);
        controller.calendarJoined(_TestCalendar());
        controller.goToMonth(august);

        expect(controller.monthsOnWayTo(DateTime(2024, 10, 1)), isEmpty);
      });
    });

    group('swipes', () {
      test('a swipe start makes the controller busy and notifies', () {
        final controller = createController(initialMonth: june);
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.calendarSwipeStarted(calendar, july);

        expect(controller.isNavigating, isTrue);
        expect(notifications, equals(1));
      });

      test('a swipe start records the pages a request would show', () {
        final controller = createController(initialMonth: june);
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);

        controller.calendarSwipeStarted(calendar, july);

        expect(controller.calendarPages, equals([june, july]));
      });

      test('a swipe toward a forbidden month records no pages', () {
        final controller = createController(
          initialMonth: june,
          maxDate: DateConstraint.fixed(DateTime(2024, 6, 30)),
        );
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);

        controller.calendarSwipeStarted(calendar, july);

        expect(controller.calendarPages, isEmpty);
        expect(controller.isNavigating, isTrue);
      });

      test('a swipe that did not move keeps the month', () {
        final controller = createController(initialMonth: june);
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);
        controller.calendarSwipeStarted(calendar, july);

        controller.calendarDone(calendar);

        expect(controller.currentMonth, equals(june));
        expect(controller.isNavigating, isFalse);
      });

      test('a swipe that landed moves the month', () {
        final controller = createController(initialMonth: june);
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);
        controller.calendarSwipeStarted(calendar, july);
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.calendarDone(calendar, landed: true);

        expect(controller.currentMonth, equals(july));
        expect(controller.isNavigating, isFalse);
        expect(controller.calendarPages, isEmpty);
        expect(notifications, equals(1));
      });

      test('other calendars follow a swipe that landed', () {
        final controller = createController(initialMonth: june);
        final swiped = _TestCalendar();
        final other = _TestCalendar();
        controller.calendarJoined(swiped);
        controller.calendarJoined(other);
        controller.calendarSwipeStarted(swiped, july);
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.calendarDone(swiped, landed: true);

        expect(controller.currentMonth, equals(july));
        expect(controller.isNavigating, isTrue);
        expect(controller.calendarPages, equals([june, july]));
        expect(notifications, equals(1));

        controller.calendarDone(other);

        expect(controller.isNavigating, isFalse);
        expect(notifications, equals(2));
      });

      test('a setting changed during a swipe leaves the pages others '
          'follow', () {
        final controller = createController(initialMonth: june);
        final swiped = _TestCalendar();
        controller.calendarJoined(swiped);
        controller.calendarJoined(_TestCalendar());
        controller.calendarSwipeStarted(swiped, july);

        controller.animationsEnabled = false;
        controller.calendarDone(swiped, landed: true);

        expect(controller.calendarPages, equals([june, july]));
      });

      test('the swiping calendar leaving ends the swipe', () {
        final controller = createController(initialMonth: june);
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);
        controller.calendarSwipeStarted(calendar, july);

        controller.calendarLeft(calendar);

        expect(controller.isNavigating, isFalse);
        expect(controller.currentMonth, equals(june));
      });
    });

    group('whenShown', () {
      test('asks each joined calendar once per call', () {
        final controller = createController();
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);

        controller.whenShown();
        controller.whenShown();

        expect(calendar.checkOnScreenCalls, equals(2));
      });

      test('asks every joined calendar', () {
        final controller = createController();
        final first = _TestCalendar();
        final second = _TestCalendar();
        controller.calendarJoined(first);
        controller.calendarJoined(second);

        controller.whenShown();

        expect(first.checkOnScreenCalls, equals(1));
        expect(second.checkOnScreenCalls, equals(1));
      });

      test('completes every caller when a calendar reports', () async {
        final controller = createController();
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);
        var first = false;
        var second = false;
        controller.whenShown().then((_) => first = true);
        controller.whenShown().then((_) => second = true);

        await Future<void>.delayed(Duration.zero);
        expect(first, isFalse);
        expect(second, isFalse);

        controller.calendarOnScreen();
        await Future<void>.delayed(Duration.zero);

        expect(first, isTrue);
        expect(second, isTrue);
      });

      test('waits for a calendar to join and report', () async {
        final controller = createController();
        var shown = false;
        controller.whenShown().then((_) => shown = true);
        final calendar = _TestCalendar();

        await Future<void>.delayed(Duration.zero);
        expect(shown, isFalse);

        controller.calendarJoined(calendar);
        expect(calendar.checkOnScreenCalls, equals(1));
        controller.calendarOnScreen();
        await Future<void>.delayed(Duration.zero);

        expect(shown, isTrue);
      });

      test('a report with nobody waiting is ignored', () async {
        final controller = createController();
        final calendar = _TestCalendar();
        controller.calendarJoined(calendar);
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.calendarOnScreen();
        var shown = false;
        controller.whenShown().then((_) => shown = true);
        await Future<void>.delayed(Duration.zero);

        expect(notifications, equals(0));
        expect(shown, isFalse);
      });
    });

    group('disposal', () {
      test('completes pending whenAtRest and whenShown callers', () async {
        final controller = CalendarController(
          initialMonth: DateTime(2024, 6, 1),
          clock: clock,
        );
        controller.calendarJoined(_TestCalendar());
        controller.goToMonth(DateTime(2024, 8, 1));
        var atRest = false;
        var shown = false;
        controller.whenAtRest().then((_) => atRest = true);
        controller.whenShown().then((_) => shown = true);
        await Future<void>.delayed(Duration.zero);

        expect(atRest, isFalse);
        expect(shown, isFalse);

        controller.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(atRest, isTrue);
        expect(shown, isTrue);
      });

      test(
        'after dispose, whenAtRest and whenShown complete at once',
        () async {
          // Disposed while busy, with a calendar joined and nobody on screen:
          // only the disposal completes the futures.
          final controller = CalendarController(
            initialMonth: DateTime(2024, 6, 1),
            clock: clock,
          );
          controller.calendarJoined(_TestCalendar());
          controller.goToMonth(DateTime(2024, 8, 1));
          controller.dispose();
          var atRest = false;
          var shown = false;

          controller.whenAtRest().then((_) => atRest = true);
          controller.whenShown().then((_) => shown = true);
          await Future<void>.delayed(Duration.zero);

          expect(atRest, isTrue);
          expect(shown, isTrue);
        },
      );

      testWidgets('after dispose, a change during a build raises the disposed '
          'assertion', (tester) async {
        final controller = CalendarController(
          initialMonth: DateTime(2024, 6, 1),
          clock: clock,
        );
        controller.dispose();

        await tester.pumpWidget(
          Builder(
            builder: (context) {
              controller.goToMonth(DateTime(2024, 8, 1));
              return const SizedBox();
            },
          ),
        );

        expect(
          tester.takeException(),
          isA<FlutterError>().having(
            (error) => error.message,
            'message',
            startsWith('A CalendarController was used after being disposed.'),
          ),
        );
      });

      test('after dispose, a navigation raises ChangeNotifier\'s disposed '
          'assertion', () {
        final controller = CalendarController(
          initialMonth: DateTime(2024, 6, 1),
          clock: clock,
        );
        controller.dispose();

        expect(
          () => controller.goToMonth(DateTime(2024, 8, 1)),
          throwsA(
            isA<FlutterError>().having(
              (error) => error.message,
              'message',
              'A CalendarController was used after being disposed.\n'
                  'Once you have called dispose() on a CalendarController, '
                  'it can no longer be used.',
            ),
          ),
        );
        expect(controller.currentMonth, equals(DateTime(2024, 8, 1)));
      });

      testWidgets('a notification deferred before dispose is dropped', (
        tester,
      ) async {
        final controller = CalendarController(
          initialMonth: DateTime(2024, 6, 1),
          clock: clock,
        );
        controller.addListener(() {});

        await tester.pumpWidget(
          Builder(
            builder: (context) {
              controller.goToMonth(DateTime(2024, 8, 1));
              controller.dispose();
              return const SizedBox();
            },
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('after dispose, a new day raises nothing', (tester) async {
        final controller = CalendarController(clock: clock);
        controller.dispose();

        clock.value = DateTime(2026, 9, 29);

        expect(tester.takeException(), isNull);
      });
    });
  });
}

/// A clock that returns [setup] until [script] is called, then the first date
/// given to [script] on its first read and the later one on every read after
/// it.
class _ScriptedClock implements ValueListenable<DateTime> {
  _ScriptedClock(this.setup);

  final DateTime setup;
  DateTime? _first;
  DateTime? _later;

  /// Reads since [script] was called.
  int scriptedReads = 0;

  void script(DateTime first, DateTime later) {
    _first = first;
    _later = later;
    scriptedReads = 0;
  }

  @override
  DateTime get value {
    final first = _first;
    if (first == null) return setup;
    scriptedReads++;
    return scriptedReads == 1 ? first : _later!;
  }

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Runs [onPaint] each time it paints.
class _Painter extends CustomPainter {
  _Painter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_Painter oldDelegate) => false;
}

class _TestCalendar implements ControlledCalendar {
  int checkOnScreenCalls = 0;

  @override
  void checkOnScreen() => checkOnScreenCalls++;
}
