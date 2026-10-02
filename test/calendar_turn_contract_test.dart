import 'dart:ui' as ui;

import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

class _Cell extends StatefulWidget {
  const _Cell({
    required this.date,
    required this.states,
    required this.disposed,
    this.updateAfterFrame = false,
    super.key,
  });

  final DateTime date;
  final Map<DateTime, _CellState> states;
  final List<DateTime> disposed;
  final bool updateAfterFrame;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    widget.states[widget.date] = this;
    ready = !widget.updateAfterFrame;
    if (widget.updateAfterFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => ready = true);
      });
    }
  }

  @override
  void dispose() {
    widget.disposed.add(widget.date);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'day ${widget.date.year}-${widget.date.month}-${widget.date.day}',
    child: ColoredBox(
      color: ready ? const Color(0xFF00FF00) : const Color(0xFFFF00FF),
      child: const SizedBox.expand(),
    ),
  );
}

Future<void> _expectReadyImage(WidgetTester tester) async {
  final image = tester.widget<PageTurnAnimation>(
    find.byType(PageTurnAnimation),
  ).image;
  final pixels = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  expect(pixels, isNotNull);
  final data = pixels!;
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  var ready = 0;
  var waiting = 0;
  for (var i = 0; i < bytes.length; i += 4) {
    if (bytes[i] == 0 && bytes[i + 1] == 255 &&
        bytes[i + 2] == 0 && bytes[i + 3] == 255) {
      ready++;
    }
    if (bytes[i] == 255 && bytes[i + 1] == 0 &&
        bytes[i + 2] == 255 && bytes[i + 3] == 255) {
      waiting++;
    }
  }
  expect(ready, greaterThan(0));
  expect(waiting, 0);
}

void main() {
  late CalendarController controller;
  late Map<DateTime, _CellState> states;
  late List<DateTime> disposed;

  setUp(() {
    controller = CalendarController(initialMonth: DateTime(2024, 6));
    states = {};
    disposed = [];
  });

  tearDown(() => controller.dispose());

  Widget subject({
    bool gesturesEnabled = true,
    bool tickerEnabled = true,
    bool updateAfterFrame = false,
    CalendarStyle style = const CalendarStyle(),
    PageTurnEdge boundEdge = PageTurnEdge.top,
    CalendarController? otherController,
    Widget Function(BuildContext, CalendarDayData)? dayBuilder,
  }) => MaterialApp(
    home: Scaffold(
      body: TickerMode(
        enabled: tickerEnabled,
        child: SizedBox(
          width: 300,
          height: 400,
          child: FlipCalendar(
            controller: otherController ?? controller,
            gesturesEnabled: gesturesEnabled,
            boundEdge: boundEdge,
            style: style,
            dayBuilder: dayBuilder ?? (context, data) => data.isCurrentMonth
                ? _Cell(
                    key: ValueKey(data.date),
                    date: data.date,
                    states: states,
                    disposed: disposed,
                    updateAfterFrame: updateAfterFrame,
                  )
                : const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );

  for (final forward in [false, true]) {
    testWidgets('page state survives a complete turn forward=$forward', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      final original = states[DateTime(2024, 6, 1)];
      final target = DateTime(2024, forward ? 7 : 5, 1);
      controller.goToMonth(target);
      await tester.pump();
      final incoming = states[target];
      expect(incoming, isNotNull);
      expect(states[DateTime(2024, 6, 1)], same(original));
      expect(disposed, isNot(contains(DateTime(2024, 6, 1))));
      if (!forward) await tester.pump();
      await tester.pump();
      expect(states[target], same(incoming));
      expect(disposed, isNot(contains(target)));
      await tester.pumpAndSettle();
      expect(controller.isNavigating, isFalse);
      expect(states[target], same(incoming));
      expect(disposed, contains(DateTime(2024, 6, 1)));
      controller.goToMonth(DateTime(2024, 6));
      await tester.pumpAndSettle();
      expect(states[DateTime(2024, 6, 1)], isNot(same(original)));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('cancelling a swipe preserves shown state forward=$forward', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      final original = states[DateTime(2024, 6, 1)];
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FlipCalendar)),
      );
      await gesture.moveBy(Offset(0, forward ? -20 : 20));
      await gesture.moveBy(Offset(0, forward ? -100 : 100));
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(controller.currentMonth, DateTime(2024, 6));
      expect(controller.isNavigating, isFalse);
      expect(states[DateTime(2024, 6, 1)], same(original));
      expect(disposed, contains(DateTime(2024, forward ? 7 : 5, 1)));
      expect(disposed, isNot(contains(DateTime(2024, 6, 1))));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('sequential turns retain each incoming page as outgoing', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    controller.goToMonth(DateTime(2024, 8));
    await tester.pump();
    final july = states[DateTime(2024, 7, 1)];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 325));
    await tester.pump(const Duration(milliseconds: 325));
    expect(states[DateTime(2024, 7, 1)], same(july));
    expect(disposed, isNot(contains(DateTime(2024, 7, 1))));
    await tester.pumpAndSettle();
    expect(controller.currentMonth, DateTime(2024, 8));
    expect(controller.isNavigating, isFalse);
    expect(disposed, contains(DateTime(2024, 7, 1)));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('restricted swipes preserve the shown page', (tester) async {
    controller.setBounds(
      DateConstraint.fixed(DateTime(2024, 6, 1)),
      DateConstraint.fixed(DateTime(2024, 6, 30)),
    );
    await tester.pumpWidget(subject());
    final original = states[DateTime(2024, 6, 1)];
    await tester.drag(find.byType(FlipCalendar), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(states[DateTime(2024, 6, 1)], same(original));
    expect(controller.currentMonth, DateTime(2024, 6));
    expect(controller.isNavigating, isFalse);
    expect(disposed, isNot(contains(DateTime(2024, 6, 1))));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a fresh swipe works after gestures are toggled mid-drag', (
    tester,
  ) async {
    await tester.pumpWidget(subject());
    final original = states[DateTime(2024, 6, 1)];
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlipCalendar)),
    );
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    await tester.pumpWidget(subject(gesturesEnabled: false));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(subject(gesturesEnabled: true));
    expect(states[DateTime(2024, 6, 1)], same(original));
    await tester.drag(find.byType(FlipCalendar), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(controller.currentMonth, DateTime(2024, 7));
    expect(controller.isNavigating, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a backward image includes its first post-frame update', (
    tester,
  ) async {
    await tester.pumpWidget(subject(updateAfterFrame: true));
    await tester.pumpAndSettle();
    controller.previousMonth();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await _expectReadyImage(tester);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a forward image includes completed future content', (
    tester,
  ) async {
    final ready = Future<String>.value('ready');
    await tester.pumpWidget(subject(dayBuilder: (context, data) =>
      FutureBuilder<String>(
        future: ready,
        builder: (context, snapshot) => ColoredBox(
          color: snapshot.hasData
              ? const Color(0xFF00FF00)
              : const Color(0xFFFF00FF),
          child: const SizedBox.expand(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    controller.nextMonth();
    await tester.pump();
    await tester.pump();
    await _expectReadyImage(tester);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('backward preparation exposes only the shown grid semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(subject());
    controller.previousMonth();
    await tester.pump();
    expect(find.bySemanticsLabel('day 2024-6-1'), findsOneWidget);
    expect(find.bySemanticsLabel('day 2024-5-1'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('day 2024-5-1'), findsOneWidget);
    expect(find.bySemanticsLabel('day 2024-6-1'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  for (final before in [true, false]) {
    for (final animated in [true, false]) {
      for (final forward in [true, false]) {
        testWidgets('a landed listener can reverse: before=$before '
            'animated=$animated forward=$forward', (tester) async {
          controller.animationsEnabled = animated;
          var returned = false;
          final landing = DateTime(2024, forward ? 7 : 5);
          void listener() {
            if (!returned && !controller.isNavigating &&
                controller.currentMonth == landing) {
              returned = true;
              controller.goToMonth(DateTime(2024, 6));
            }
          }
          if (before) controller.addListener(listener);
          await tester.pumpWidget(subject());
          if (!before) controller.addListener(listener);
          await tester.drag(
            find.byType(FlipCalendar),
            Offset(0, forward ? -200 : 200),
          );
          await tester.pumpAndSettle();
          expect(returned, isTrue);
          expect(controller.currentMonth, DateTime(2024, 6));
          expect(controller.isNavigating, isFalse);
          expect(tester.takeException(), isNull);
          controller.removeListener(listener);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets('an invalidated landing reports after its restored frame', (
    tester,
  ) async {
    controller.animationsEnabled = false;
    await tester.pumpWidget(subject());
    await tester.drag(find.byType(FlipCalendar), const Offset(0, -200));
    var atRest = false;
    controller.whenAtRest().then((_) => atRest = true);
    controller.setBounds(null, DateConstraint.fixed(DateTime(2024, 6, 30)));
    await tester.pump();
    expect(controller.isNavigating, isTrue);
    expect(atRest, isFalse);
    await tester.pump();
    expect(controller.isNavigating, isFalse);
    expect(atRest, isTrue);
    expect(controller.currentMonth, DateTime(2024, 6));
    expect(find.byType(_Cell), findsNWidgets(30));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final interruption in [
    'detach', 'controller', 'gestures', 'edge', 'ticker', 'bounds',
  ]) {
    testWidgets('backward preparation handles $interruption', (tester) async {
      await tester.pumpWidget(subject());
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FlipCalendar)),
      );
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      final replacement = CalendarController(initialMonth: DateTime(2024, 8));
      addTearDown(replacement.dispose);
      switch (interruption) {
        case 'detach':
          await tester.pumpWidget(const SizedBox.shrink());
        case 'controller':
          await tester.pumpWidget(subject(otherController: replacement));
        case 'gestures':
          await tester.pumpWidget(subject(gesturesEnabled: false));
        case 'edge':
          await tester.pumpWidget(subject(boundEdge: PageTurnEdge.bottom));
        case 'ticker':
          await tester.pumpWidget(subject(tickerEnabled: false));
        case 'bounds':
          controller.setBounds(
            DateConstraint.fixed(DateTime(2024, 6)), null,
          );
      }
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(controller.isNavigating, isFalse);
      expect(replacement.isNavigating, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('the selected cell key belongs to one month page', (
    tester,
  ) async {
    final key = GlobalKey();
    var selected = DateTime(2024, 6, 1);
    Widget cell(BuildContext context, CalendarDayData data) => SizedBox.expand(
      key: data.isCurrentMonth && data.date == selected ? key : null,
    );
    await tester.pumpWidget(subject(dayBuilder: cell));
    for (final forward in [false, true]) {
      selected = DateTime(2024, 6, forward ? 30 : 1);
      await tester.pumpWidget(subject(dayBuilder: cell));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FlipCalendar)),
      );
      await gesture.moveBy(Offset(0, forward ? -20 : 20));
      await gesture.moveBy(Offset(0, forward ? -100 : 100));
      await tester.pump();
      expect(find.byKey(key, skipOffstage: false), findsOneWidget);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.byKey(key), findsOneWidget);
      expect(tester.takeException(), isNull);
      controller.goToMonth(DateTime(2024, forward ? 7 : 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      controller.goToMonth(DateTime(2024, 6));
      await tester.pumpAndSettle();
      expect(find.byKey(key), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shared calendars settle before a listener reverses a swipe', (
    tester,
  ) async {
    var returned = false;
    controller.addListener(() {
      if (!returned && !controller.isNavigating &&
          controller.currentMonth == DateTime(2024, 7)) {
        returned = true;
        controller.previousMonth();
      }
    });
    Widget calendar() => SizedBox(
      width: 300,
      height: 400,
      child: FlipCalendar(
        controller: controller,
        dayBuilder: (context, data) => Text('${data.date.month}'),
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Row(children: [calendar(), calendar()])),
    ));
    await tester.drag(find.byType(FlipCalendar).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(controller.currentMonth, DateTime(2024, 6));
    expect(controller.isNavigating, isFalse);
    expect(find.byType(PageTurnAnimation), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sub-threshold jitter starts no restricted navigation', (
    tester,
  ) async {
    controller.setBounds(
      DateConstraint.fixed(DateTime(2024, 6)),
      DateConstraint.fixed(DateTime(2024, 6, 30)),
    );
    var notifications = 0;
    var haptics = 0;
    controller.addListener(() => notifications++);
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 300,
        height: 400,
        child: FlipCalendar(
          controller: controller,
          onHapticFeedback: (_) => haptics++,
          dayBuilder: (context, data) => const SizedBox.expand(),
        ),
      ),
    ));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlipCalendar)),
    );
    await gesture.moveBy(const Offset(0, -3));
    await tester.pump();
    expect(controller.isNavigating, isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(notifications, 0);
    expect(haptics, 0);
    expect(find.byType(PageTurnAnimation), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a same-month restricted turn keeps its underneath page', (
    tester,
  ) async {
    controller.dispose();
    controller = CalendarController(initialMonth: DateTime(-271821, 5));
    await tester.pumpWidget(subject());
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlipCalendar)),
    );
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PageTurnAnimation), findsOneWidget);
    expect(find.byType(_Cell), findsNWidgets(31));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(controller.currentMonth, DateTime(-271821, 5));
    expect(controller.isNavigating, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final swipe in [false, true]) {
    testWidgets('duration changes affect the next operation: swipe=$swipe', (
      tester,
    ) async {
      const initial = CalendarStyle(
        animationDuration: Duration(milliseconds: 800),
      );
      const updated = CalendarStyle(
        animationDuration: Duration(milliseconds: 1200),
      );
      await tester.pumpWidget(subject(style: initial));
      if (swipe) {
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(FlipCalendar)),
        );
        await gesture.moveBy(const Offset(0, -20));
        await gesture.moveBy(const Offset(0, -200));
        await tester.pump();
        await tester.pump();
        await tester.pumpWidget(subject(style: updated));
        final animation = tester.widget<PageTurnAnimation>(
          find.byType(PageTurnAnimation),
        ).animation as AnimationController;
        expect(animation.duration, initial.animationDuration);
        await gesture.up();
      } else {
        controller.nextMonth();
        await tester.pump();
        await tester.pumpWidget(subject(style: updated));
        final animation = tester.widget<PageTurnAnimation>(
          find.byType(PageTurnAnimation),
        ).animation as AnimationController;
        expect(animation.duration, initial.animationDuration);
      }
      await tester.pumpAndSettle();
      controller.nextMonth();
      await tester.pump();
      await tester.pump();
      final animation = tester.widget<PageTurnAnimation>(
        find.byType(PageTurnAnimation),
      ).animation as AnimationController;
      expect(animation.duration, updated.animationDuration);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
