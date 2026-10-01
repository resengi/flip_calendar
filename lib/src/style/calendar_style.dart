/// @docImport '../calendar/flip_calendar.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

/// Style configuration for [FlipCalendar].
///
/// Every field has a default. [copyWith] replaces fields supplied with a
/// non-null value. Omitted arguments and null keep the existing field,
/// including [weekdayTextStyle].
///
/// Each field whose doc states a rule is checked when a calendar builds with
/// this style: a value that breaks its rule makes the build throw an
/// [ArgumentError] that names the field.
class CalendarStyle {
  // -- Factories --

  /// Light theme (identical to default constructor).
  factory CalendarStyle.light() => const CalendarStyle();

  /// Dark theme.
  factory CalendarStyle.dark() => const CalendarStyle(
    calendarBackground: Color(0xFF212121),
    gridLineColor: Color(0xFF424242),
    weekdayHeaderBackground: Color(0xFF303030),
    weekdayHeaderTextColor: Color(0xFFFFFFFF),
    dayTextColor: Color(0xFFFFFFFF),
    disabledDayTextColor: Color(0xFF757575),
    todayBorderColor: Color(0xFF64B5F6),
    selectedDayBackground: Color(0x3364B5F6),
    disabledDateBackground: Color(0x33757575),
  );

  const CalendarStyle({
    // Background
    this.calendarBackground = const Color(0xFFFFFFFF),
    // Padding
    this.padding = EdgeInsets.zero,
    // Border radius
    this.borderRadius = BorderRadius.zero,
    // Grid
    this.gridLineColor = const Color(0xFFE0E0E0),
    this.gridLineWidth = 1.0,
    // Weekday header
    this.weekdayHeaderBackground = const Color(0xFFF5F5F5),
    this.weekdayHeaderTextColor = const Color(0xDD000000),
    this.weekdayHeaderHeight = 40.0,
    this.weekdayTextStyle,
    this.weekdayNames = defaultWeekdayNames,
    // Day cells
    this.dayTextColor = const Color(0xDD000000),
    this.disabledDayTextColor = const Color(0xFF9E9E9E),
    this.dayTextSize = 16.0,
    // Today indicator
    this.todayBorderColor = const Color(0xFF2196F3),
    this.todayBorderWidth = 2.0,
    this.todayBorderRadius = const BorderRadius.all(Radius.circular(4)),
    this.todayMargin = const EdgeInsets.all(2),
    // Selection
    this.selectedDayBackground = const Color(0x1A2196F3),
    // Disabled dates
    this.disabledDateBackground = const Color(0x1A9E9E9E),
    // Animation
    this.animationDuration = const Duration(milliseconds: 650),
    this.animationCurve = Curves.decelerate,
    this.pageTurnStyle = const PageTurnStyle(),
    // Gestures
    this.flickDistanceThreshold = 0.05,
    this.flickMaxDuration = const Duration(milliseconds: 500),
    this.dragBoxSizePercentage = 0.7,
    this.dragProgressThreshold = 0.3,
  });

  // -- Background --

  /// Background color of each page, painted behind the weekday header and the
  /// grid, inside [borderRadius]'s clip.
  final Color calendarBackground;

  // -- Padding --

  /// Padding inside the calendar background, around the grid content.
  /// Included in animation image captures so the page-turn effect
  /// shows the padded area as part of the "page". Every side must be finite
  /// and not negative.
  final EdgeInsets padding;

  // -- Border Radius --

  /// Border radius for the calendar's outer edges.
  /// Applied as a clip so content (including captured animation images)
  /// respects the rounding. Every radius must be finite and not negative.
  final BorderRadius borderRadius;

  // -- Grid --

  /// Color of the grid lines and the weekday header's lines.
  final Color gridLineColor;

  /// Width of the grid lines and the weekday header's lines; 0 draws no
  /// line. Must be finite and not negative.
  final double gridLineWidth;

  // -- Weekday Header --

  /// Background color of the weekday header row.
  final Color weekdayHeaderBackground;

  /// Text color for weekday names (used in default text style).
  final Color weekdayHeaderTextColor;

  /// Height of the weekday header row, limited by the available content
  /// height. Must be finite and not negative.
  final double weekdayHeaderHeight;

  /// Custom text style for weekday names. If null, uses a default style.
  final TextStyle? weekdayTextStyle;

  /// Weekday names starting from Sunday. Must contain exactly 7 strings.
  /// Automatically rotated based on [FlipCalendar.firstDayOfWeek].
  final List<String> weekdayNames;

  // -- Day Cells --

  /// Text color for day numbers. The calendar does not draw with it; a day
  /// builder can read it from this style.
  final Color dayTextColor;

  /// Text color for disabled days. The calendar does not draw with it; a day
  /// builder can read it from this style.
  final Color disabledDayTextColor;

  /// Font size for day numbers. The calendar does not draw with it; a day
  /// builder can read it from this style. Must be finite and not negative.
  final double dayTextSize;

  // -- Today Indicator --

  /// Border color for today's cell.
  final Color todayBorderColor;

  /// Border width for today's cell; 0 draws no border. Must be finite and not
  /// negative.
  final double todayBorderWidth;

  /// Border radius for today's cell. Every radius must be finite and not
  /// negative.
  final BorderRadius todayBorderRadius;

  /// Margin around today's cell content. Every side must be finite and not
  /// negative.
  final EdgeInsets todayMargin;

  // -- Selection --

  /// Background color for the selected day's cell. A selected day that is
  /// disabled gets [disabledDateBackground] instead.
  final Color selectedDayBackground;

  // -- Disabled Dates --

  /// Background color for disabled date cells.
  final Color disabledDateBackground;

  // -- Animation --

  /// Duration of the page-turn animation. A navigation that turns several
  /// pages divides it equally among them, rounded down to the microsecond.
  /// Must not be negative.
  final Duration animationDuration;

  /// Easing curve for the part of a page turn that runs by itself: each turn
  /// of a navigation, and a swipe's turn after release, from where the
  /// release leaves the page. While a swipe is dragged, the page follows the
  /// finger linearly.
  final Curve animationCurve;

  /// Style for the page-turn effect (from `page_turn_animation` package).
  final PageTurnStyle pageTurnStyle;

  // -- Gestures --

  /// With [flickMaxDuration], sets the flick speed: this fraction of the
  /// calendar's size along the swipe axis per [flickMaxDuration]. A release
  /// faster than that speed, that has also moved more than Flutter's touch
  /// slop just before it, is a flick: in the swipe's direction it completes
  /// the swipe whatever its progress, and against it it does not. Must be
  /// finite and greater than 0.
  final double flickDistanceThreshold;

  /// With [flickDistanceThreshold], sets the flick speed. Must be greater
  /// than zero.
  final Duration flickMaxDuration;

  /// The fraction of the calendar's size along the swipe axis that a drag
  /// covers to reach progress 1. Must be finite and greater than 0.
  final double dragBoxSizePercentage;

  /// The progress at or above which a released drag that is not a flick
  /// completes the swipe. Must be greater than 0 and at most 1.
  final double dragProgressThreshold;

  // -- Defaults --

  /// Default weekday names starting from Sunday.
  static const List<String> defaultWeekdayNames = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  // -- copyWith --

  CalendarStyle copyWith({
    Color? calendarBackground,
    EdgeInsets? padding,
    BorderRadius? borderRadius,
    Color? gridLineColor,
    double? gridLineWidth,
    Color? weekdayHeaderBackground,
    Color? weekdayHeaderTextColor,
    double? weekdayHeaderHeight,
    TextStyle? weekdayTextStyle,
    List<String>? weekdayNames,
    Color? dayTextColor,
    Color? disabledDayTextColor,
    double? dayTextSize,
    Color? todayBorderColor,
    double? todayBorderWidth,
    BorderRadius? todayBorderRadius,
    EdgeInsets? todayMargin,
    Color? selectedDayBackground,
    Color? disabledDateBackground,
    Duration? animationDuration,
    Curve? animationCurve,
    PageTurnStyle? pageTurnStyle,
    double? flickDistanceThreshold,
    Duration? flickMaxDuration,
    double? dragBoxSizePercentage,
    double? dragProgressThreshold,
  }) {
    return CalendarStyle(
      calendarBackground: calendarBackground ?? this.calendarBackground,
      padding: padding ?? this.padding,
      borderRadius: borderRadius ?? this.borderRadius,
      gridLineColor: gridLineColor ?? this.gridLineColor,
      gridLineWidth: gridLineWidth ?? this.gridLineWidth,
      weekdayHeaderBackground:
          weekdayHeaderBackground ?? this.weekdayHeaderBackground,
      weekdayHeaderTextColor:
          weekdayHeaderTextColor ?? this.weekdayHeaderTextColor,
      weekdayHeaderHeight: weekdayHeaderHeight ?? this.weekdayHeaderHeight,
      weekdayTextStyle: weekdayTextStyle ?? this.weekdayTextStyle,
      weekdayNames: weekdayNames ?? this.weekdayNames,
      dayTextColor: dayTextColor ?? this.dayTextColor,
      disabledDayTextColor: disabledDayTextColor ?? this.disabledDayTextColor,
      dayTextSize: dayTextSize ?? this.dayTextSize,
      todayBorderColor: todayBorderColor ?? this.todayBorderColor,
      todayBorderWidth: todayBorderWidth ?? this.todayBorderWidth,
      todayBorderRadius: todayBorderRadius ?? this.todayBorderRadius,
      todayMargin: todayMargin ?? this.todayMargin,
      selectedDayBackground:
          selectedDayBackground ?? this.selectedDayBackground,
      disabledDateBackground:
          disabledDateBackground ?? this.disabledDateBackground,
      animationDuration: animationDuration ?? this.animationDuration,
      animationCurve: animationCurve ?? this.animationCurve,
      pageTurnStyle: pageTurnStyle ?? this.pageTurnStyle,
      flickDistanceThreshold:
          flickDistanceThreshold ?? this.flickDistanceThreshold,
      flickMaxDuration: flickMaxDuration ?? this.flickMaxDuration,
      dragBoxSizePercentage:
          dragBoxSizePercentage ?? this.dragBoxSizePercentage,
      dragProgressThreshold:
          dragProgressThreshold ?? this.dragProgressThreshold,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CalendarStyle) return false;

    return other.calendarBackground == calendarBackground &&
        other.padding == padding &&
        other.borderRadius == borderRadius &&
        other.gridLineColor == gridLineColor &&
        other.gridLineWidth == gridLineWidth &&
        other.weekdayHeaderBackground == weekdayHeaderBackground &&
        other.weekdayHeaderTextColor == weekdayHeaderTextColor &&
        other.weekdayHeaderHeight == weekdayHeaderHeight &&
        other.weekdayTextStyle == weekdayTextStyle &&
        listEquals(other.weekdayNames, weekdayNames) &&
        other.dayTextColor == dayTextColor &&
        other.disabledDayTextColor == disabledDayTextColor &&
        other.dayTextSize == dayTextSize &&
        other.todayBorderColor == todayBorderColor &&
        other.todayBorderWidth == todayBorderWidth &&
        other.todayBorderRadius == todayBorderRadius &&
        other.todayMargin == todayMargin &&
        other.selectedDayBackground == selectedDayBackground &&
        other.disabledDateBackground == disabledDateBackground &&
        other.animationDuration == animationDuration &&
        other.animationCurve == animationCurve &&
        other.pageTurnStyle == pageTurnStyle &&
        other.flickDistanceThreshold == flickDistanceThreshold &&
        other.flickMaxDuration == flickMaxDuration &&
        other.dragBoxSizePercentage == dragBoxSizePercentage &&
        other.dragProgressThreshold == dragProgressThreshold;
  }

  @override
  int get hashCode => Object.hashAll([
    calendarBackground,
    padding,
    borderRadius,
    gridLineColor,
    gridLineWidth,
    weekdayHeaderBackground,
    weekdayHeaderTextColor,
    weekdayHeaderHeight,
    weekdayTextStyle,
    Object.hashAll(weekdayNames),
    dayTextColor,
    disabledDayTextColor,
    dayTextSize,
    todayBorderColor,
    todayBorderWidth,
    todayBorderRadius,
    todayMargin,
    selectedDayBackground,
    disabledDateBackground,
    animationDuration,
    animationCurve,
    pageTurnStyle,
    flickDistanceThreshold,
    flickMaxDuration,
    dragBoxSizePercentage,
    dragProgressThreshold,
  ]);
}
