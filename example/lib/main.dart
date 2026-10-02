import 'dart:async';

import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter/material.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

void main() => runApp(const FlipCalendarExample());

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

class FlipCalendarExample extends StatelessWidget {
  const FlipCalendarExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flip Calendar Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: ExampleColors.background,
      ),
      home: const CalendarExamplePage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Colors
// ---------------------------------------------------------------------------

abstract final class ExampleColors {
  // Backgrounds
  static const background = Color(0xFFF5EFE0); // Warm sand
  static const cardBackground = Color(0xFFFFFDF7); // Cream white
  static const cardShadow = Color(0xFF5C4D40); // Warm dark brown
  static const calendarBackground = Color(0xFFFAECC7); // Warm ivory-yellow
  static const headerBackground = Color(0xFFEDCB92); // Parchment
  static const gridLines = Color(0xFFC4B5A3); // Light tan

  // Text
  static const textPrimary = Color(0xFF2B2320); // Warm ink
  static const textSecondary = Color(0xFF8C7B6B); // Warm taupe
  static const textDisabled = Color(0xFFBBAA99);

  // Accent / today
  static const accent = Color(0xFFC85C51); // Rich muted red
  static const selectedDay = Color(0x33C85C51);

  // Event dot colors
  static const eventRed = Color(0xFFC85C51);
  static const eventRose = Color(0xFFE8A594);
  static const eventGreen = Color(0xFF6A9E6A);
  static const eventAmber = Color(0xFFC9A84E);
  static const eventBlue = Color(0xFF6B9BD2);
  static const eventPurple = Color(0xFF9B8EC4);
  static const eventTeal = Color(0xFF5FADA0);
}

// ---------------------------------------------------------------------------
// Sample event data
// ---------------------------------------------------------------------------

class SampleEvent {
  const SampleEvent(this.title, this.color);
  final String title;
  final Color color;
}

/// Returns some hard-coded events by day of the month, shown on those days of
/// every month so the calendar isn't completely empty.
Map<int, List<SampleEvent>> _buildSampleEvents() {
  return {
    3: [
      const SampleEvent('Team standup', ExampleColors.eventBlue),
      const SampleEvent('Dentist', ExampleColors.eventAmber),
    ],
    7: [const SampleEvent('Sprint review', ExampleColors.eventPurple)],
    10: [
      const SampleEvent('Grocery run', ExampleColors.eventGreen),
      const SampleEvent('Call Mom', ExampleColors.eventBlue),
      const SampleEvent('Gym', ExampleColors.eventRed),
    ],
    15: [
      const SampleEvent('Launch day 🚀', ExampleColors.eventPurple),
      const SampleEvent('Team dinner', ExampleColors.eventRose),
    ],
    21: [const SampleEvent('1:1 w/ manager', ExampleColors.eventTeal)],
    25: [
      const SampleEvent('Haircut', ExampleColors.eventGreen),
      const SampleEvent('Date night', ExampleColors.eventRed),
    ],
  };
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

class CalendarExamplePage extends StatefulWidget {
  const CalendarExamplePage({super.key});

  @override
  State<CalendarExamplePage> createState() => _CalendarExamplePageState();
}

class _CalendarExamplePageState extends State<CalendarExamplePage> {
  /// The calendar's today, updated every minute, so the calendar moves to the
  /// next day while the app is open.
  final _clock = ValueNotifier<DateTime>(DateTime.now());
  late final Timer _clockTimer;
  late final CalendarController _controller;
  DateTime? _selectedDate;
  bool _isNavigating = false;
  PageTurnEdge _boundEdge = PageTurnEdge.top;

  final _sampleEvents = _buildSampleEvents();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _clock.value = DateTime.now(),
    );
    _controller = CalendarController(
      clock: _clock,
      maxDate: DateConstraint.today(),
      multiMonthAnimationMode: MultiMonthAnimationMode.directJump,
    );
    _controller.addListener(_onCalendarChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onCalendarChanged);
    _controller.dispose();
    // The clock must outlive the controller.
    _clockTimer.cancel();
    _clock.dispose();
    super.dispose();
  }

  void _onCalendarChanged() {
    final navigating = _controller.isNavigating;
    if (navigating != _isNavigating) {
      setState(() => _isNavigating = navigating);
    }
  }

  void _onDayTapped(DateTime date) {
    setState(() => _selectedDate = date);
    final current = _controller.currentMonth;
    if (date.year != current.year || date.month != current.month) {
      _controller.goToMonth(date);
    }
  }

  // -- Header navigation ---------------------------------------------------

  /// Turns to today's month, then clears the selection once the page rests
  /// there.
  ///
  /// A calendar turns its pages only while it is on screen, so this first
  /// waits for it to be, as a host would for a calendar on another tab.
  Future<void> _goToToday() async {
    await _controller.whenShown();
    if (!mounted) return;
    _controller.goToToday();
    await _controller.whenAtRest();
    if (!mounted) return;
    setState(() => _selectedDate = null);
  }

  // -- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              _CalendarHeader(
                currentMonth: _controller.currentMonth,
                enabled: !_isNavigating,
                onPrevious: _controller.previousMonth,
                onNext: _controller.nextMonth,
                onToday: _goToToday,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: ExampleColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: ExampleColors.cardShadow.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FlipCalendar(
                    controller: _controller,
                    selectedDate: _selectedDate,
                    onDayTap: _onDayTapped,
                    boundEdge: _boundEdge,
                    style: const CalendarStyle(
                      padding: EdgeInsets.all(20),
                      calendarBackground: ExampleColors.calendarBackground,
                      weekdayHeaderBackground: ExampleColors.headerBackground,
                      weekdayHeaderTextColor: ExampleColors.textSecondary,
                      animationDuration: Duration(milliseconds: 400),
                      todayBorderColor: ExampleColors.accent,
                      todayBorderWidth: 1.5,
                      todayBorderRadius: BorderRadius.all(Radius.circular(6)),
                      todayMargin: EdgeInsets.all(2),
                      selectedDayBackground: ExampleColors.selectedDay,
                      gridLineColor: ExampleColors.gridLines,
                      gridLineWidth: 0.5,
                      disabledDateBackground: Color(0x0D8C7B6B),
                      weekdayTextStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ExampleColors.textSecondary,
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      pageTurnStyle: PageTurnStyle(
                        shadowOpacity: 0.5,
                        curlIntensity: 1.0,
                        shadowColor: ExampleColors.cardShadow,
                      ),
                    ),
                    dayBuilder: (_, dayData) {
                      // Only show events for the currently displayed month
                      final events = dayData.isCurrentMonth
                          ? _sampleEvents[dayData.date.day]
                          : null;

                      return _DayCell(data: dayData, events: events);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _BoundEdgePicker(
                value: _boundEdge,
                onChanged: (edge) => setState(() => _boundEdge = edge),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar header
// ---------------------------------------------------------------------------

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.currentMonth,
    required this.enabled,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime currentMonth;
  final bool enabled;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = (constraints.maxWidth * 0.06).clamp(24.0, 36.0);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: enabled ? onPrevious : null,
                  color: ExampleColors.textPrimary,
                  iconSize: fontSize * 0.8,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: enabled ? onToday : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _months[currentMonth.month - 1],
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            color: ExampleColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(width: fontSize * 0.5),
                        Text(
                          '${currentMonth.year}',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w300,
                            color: ExampleColors.textSecondary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: enabled ? onNext : null,
                  color: ExampleColors.textPrimary,
                  iconSize: fontSize * 0.8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Bound edge picker
// ---------------------------------------------------------------------------

class _BoundEdgePicker extends StatelessWidget {
  const _BoundEdgePicker({required this.value, required this.onChanged});

  final PageTurnEdge value;
  final ValueChanged<PageTurnEdge> onChanged;

  static const _labels = {
    PageTurnEdge.top: 'Top',
    PageTurnEdge.bottom: 'Bottom',
    PageTurnEdge.left: 'Left',
    PageTurnEdge.right: 'Right',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ExampleColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: ExampleColors.cardShadow.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Bound Edge',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ExampleColors.textPrimary,
            ),
          ),
          DropdownButton<PageTurnEdge>(
            value: value,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(8),
            dropdownColor: ExampleColors.cardBackground,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ExampleColors.textPrimary,
            ),
            icon: const Icon(
              Icons.unfold_more,
              size: 18,
              color: ExampleColors.textSecondary,
            ),
            items: PageTurnEdge.values.map((edge) {
              return DropdownMenuItem(value: edge, child: Text(_labels[edge]!));
            }).toList(),
            onChanged: (edge) {
              if (edge != null) onChanged(edge);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day cell
// ---------------------------------------------------------------------------

class _DayCell extends StatelessWidget {
  const _DayCell({required this.data, this.events});

  final CalendarDayData data;
  final List<SampleEvent>? events;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      child: Opacity(
        opacity: data.isCurrentMonth ? 1.0 : 0.3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day number
            Padding(
              padding: const EdgeInsets.only(left: 2, top: 1),
              child: Text(
                '${data.date.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: data.isToday ? FontWeight.w700 : FontWeight.w500,
                  color: !data.isEnabled
                      ? ExampleColors.textDisabled
                      : data.isToday
                      ? ExampleColors.accent
                      : ExampleColors.textPrimary,
                ),
              ),
            ),

            // Event dots
            if (events != null && events!.isNotEmpty) ...[
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 2),
                child: Row(
                  children: events!
                      .take(4)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: e.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
