import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

void main() {
  group('CalendarStyle', () {
    /// A new style whose every field differs from the default style's.
    CalendarStyle nonDefaultStyle() {
      return CalendarStyle(
        calendarBackground: const Color(0xFF000001),
        padding: const EdgeInsets.all(1),
        borderRadius: const BorderRadius.all(Radius.circular(1)),
        gridLineColor: const Color(0xFF000002),
        gridLineWidth: 2,
        weekdayHeaderBackground: const Color(0xFF000003),
        weekdayHeaderTextColor: const Color(0xFF000004),
        weekdayHeaderHeight: 41,
        weekdayTextStyle: const TextStyle(fontSize: 1),
        // A new list on every call, so two such styles are not one instance
        // and hold equal lists that are not one list.
        weekdayNames: List.of(const ['S', 'M', 'T', 'W', 'T', 'F', 'S']),
        dayTextColor: const Color(0xFF000005),
        disabledDayTextColor: const Color(0xFF000006),
        dayTextSize: 17,
        todayBorderColor: const Color(0xFF000007),
        todayBorderWidth: 3,
        todayBorderRadius: const BorderRadius.all(Radius.circular(5)),
        todayMargin: const EdgeInsets.all(3),
        selectedDayBackground: const Color(0xFF000008),
        disabledDateBackground: const Color(0xFF000009),
        animationDuration: const Duration(milliseconds: 1),
        animationCurve: Curves.linear,
        dragCurve: Curves.decelerate,
        pageTurnStyle: const PageTurnStyle(segments: 1),
        flickDistanceThreshold: 0.5,
        flickMaxDuration: const Duration(milliseconds: 1),
        dragBoxSizePercentage: 0.5,
        dragProgressThreshold: 0.5,
      );
    }

    test('the default style has the default value in every field', () {
      const style = CalendarStyle();
      expect(style.calendarBackground, equals(const Color(0xFFFFFFFF)));
      expect(style.padding, equals(EdgeInsets.zero));
      expect(style.borderRadius, equals(BorderRadius.zero));
      expect(style.gridLineColor, equals(const Color(0xFFE0E0E0)));
      expect(style.gridLineWidth, equals(1.0));
      expect(style.weekdayHeaderBackground, equals(const Color(0xFFF5F5F5)));
      expect(style.weekdayHeaderTextColor, equals(const Color(0xDD000000)));
      expect(style.weekdayHeaderHeight, equals(40.0));
      expect(style.weekdayTextStyle, isNull);
      expect(
        style.weekdayNames,
        equals(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']),
      );
      expect(style.dayTextColor, equals(const Color(0xDD000000)));
      expect(style.disabledDayTextColor, equals(const Color(0xFF9E9E9E)));
      expect(style.dayTextSize, equals(16.0));
      expect(style.todayBorderColor, equals(const Color(0xFF2196F3)));
      expect(style.todayBorderWidth, equals(2.0));
      expect(
        style.todayBorderRadius,
        equals(const BorderRadius.all(Radius.circular(4))),
      );
      expect(style.todayMargin, equals(const EdgeInsets.all(2)));
      expect(style.selectedDayBackground, equals(const Color(0x1A2196F3)));
      expect(style.disabledDateBackground, equals(const Color(0x1A9E9E9E)));
      expect(
        style.animationDuration,
        equals(const Duration(milliseconds: 650)),
      );
      expect(style.animationCurve, equals(Curves.decelerate));
      expect(style.dragCurve, equals(Curves.linear));
      expect(style.pageTurnStyle, equals(const PageTurnStyle()));
      expect(style.flickDistanceThreshold, equals(0.05));
      expect(style.flickMaxDuration, equals(const Duration(milliseconds: 500)));
      expect(style.dragBoxSizePercentage, equals(0.7));
      expect(style.dragProgressThreshold, equals(0.3));
    });

    test('light() is the default style', () {
      expect(CalendarStyle.light(), equals(const CalendarStyle()));
    });

    test('dark() is the default style with nine dark colours', () {
      final dark = CalendarStyle.dark();
      expect(dark.calendarBackground, equals(const Color(0xFF212121)));
      expect(dark.gridLineColor, equals(const Color(0xFF424242)));
      expect(dark.weekdayHeaderBackground, equals(const Color(0xFF303030)));
      expect(dark.weekdayHeaderTextColor, equals(const Color(0xFFFFFFFF)));
      expect(dark.dayTextColor, equals(const Color(0xFFFFFFFF)));
      expect(dark.disabledDayTextColor, equals(const Color(0xFF757575)));
      expect(dark.todayBorderColor, equals(const Color(0xFF64B5F6)));
      expect(dark.selectedDayBackground, equals(const Color(0x3364B5F6)));
      expect(dark.disabledDateBackground, equals(const Color(0x33757575)));

      // Every other field keeps its default.
      expect(
        dark,
        equals(
          const CalendarStyle().copyWith(
            calendarBackground: dark.calendarBackground,
            gridLineColor: dark.gridLineColor,
            weekdayHeaderBackground: dark.weekdayHeaderBackground,
            weekdayHeaderTextColor: dark.weekdayHeaderTextColor,
            dayTextColor: dark.dayTextColor,
            disabledDayTextColor: dark.disabledDayTextColor,
            todayBorderColor: dark.todayBorderColor,
            selectedDayBackground: dark.selectedDayBackground,
            disabledDateBackground: dark.disabledDateBackground,
          ),
        ),
      );
    });

    test('copyWith replaces every field it is given', () {
      final other = nonDefaultStyle();

      expect(
        const CalendarStyle().copyWith(
          calendarBackground: other.calendarBackground,
          padding: other.padding,
          borderRadius: other.borderRadius,
          gridLineColor: other.gridLineColor,
          gridLineWidth: other.gridLineWidth,
          weekdayHeaderBackground: other.weekdayHeaderBackground,
          weekdayHeaderTextColor: other.weekdayHeaderTextColor,
          weekdayHeaderHeight: other.weekdayHeaderHeight,
          weekdayTextStyle: other.weekdayTextStyle,
          weekdayNames: other.weekdayNames,
          dayTextColor: other.dayTextColor,
          disabledDayTextColor: other.disabledDayTextColor,
          dayTextSize: other.dayTextSize,
          todayBorderColor: other.todayBorderColor,
          todayBorderWidth: other.todayBorderWidth,
          todayBorderRadius: other.todayBorderRadius,
          todayMargin: other.todayMargin,
          selectedDayBackground: other.selectedDayBackground,
          disabledDateBackground: other.disabledDateBackground,
          animationDuration: other.animationDuration,
          animationCurve: other.animationCurve,
          dragCurve: other.dragCurve,
          pageTurnStyle: other.pageTurnStyle,
          flickDistanceThreshold: other.flickDistanceThreshold,
          flickMaxDuration: other.flickMaxDuration,
          dragBoxSizePercentage: other.dragBoxSizePercentage,
          dragProgressThreshold: other.dragProgressThreshold,
        ),
        equals(other),
      );
    });

    test('copyWith keeps every field it is not given', () {
      final style = nonDefaultStyle();

      expect(style.copyWith(), equals(style));
    });

    test('styles with equal fields are equal and have the same hash code', () {
      final a = nonDefaultStyle();
      final b = nonDefaultStyle();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('styles that differ in any one field are not equal', () {
      final other = nonDefaultStyle();
      final differInOneField = {
        'calendarBackground': CalendarStyle(
          calendarBackground: other.calendarBackground,
        ),
        'padding': CalendarStyle(padding: other.padding),
        'borderRadius': CalendarStyle(borderRadius: other.borderRadius),
        'gridLineColor': CalendarStyle(gridLineColor: other.gridLineColor),
        'gridLineWidth': CalendarStyle(gridLineWidth: other.gridLineWidth),
        'weekdayHeaderBackground': CalendarStyle(
          weekdayHeaderBackground: other.weekdayHeaderBackground,
        ),
        'weekdayHeaderTextColor': CalendarStyle(
          weekdayHeaderTextColor: other.weekdayHeaderTextColor,
        ),
        'weekdayHeaderHeight': CalendarStyle(
          weekdayHeaderHeight: other.weekdayHeaderHeight,
        ),
        'weekdayTextStyle': CalendarStyle(
          weekdayTextStyle: other.weekdayTextStyle,
        ),
        'weekdayNames': CalendarStyle(weekdayNames: other.weekdayNames),
        'dayTextColor': CalendarStyle(dayTextColor: other.dayTextColor),
        'disabledDayTextColor': CalendarStyle(
          disabledDayTextColor: other.disabledDayTextColor,
        ),
        'dayTextSize': CalendarStyle(dayTextSize: other.dayTextSize),
        'todayBorderColor': CalendarStyle(
          todayBorderColor: other.todayBorderColor,
        ),
        'todayBorderWidth': CalendarStyle(
          todayBorderWidth: other.todayBorderWidth,
        ),
        'todayBorderRadius': CalendarStyle(
          todayBorderRadius: other.todayBorderRadius,
        ),
        'todayMargin': CalendarStyle(todayMargin: other.todayMargin),
        'selectedDayBackground': CalendarStyle(
          selectedDayBackground: other.selectedDayBackground,
        ),
        'disabledDateBackground': CalendarStyle(
          disabledDateBackground: other.disabledDateBackground,
        ),
        'animationDuration': CalendarStyle(
          animationDuration: other.animationDuration,
        ),
        'animationCurve': CalendarStyle(animationCurve: other.animationCurve),
        'dragCurve': CalendarStyle(dragCurve: other.dragCurve),
        'pageTurnStyle': CalendarStyle(pageTurnStyle: other.pageTurnStyle),
        'flickDistanceThreshold': CalendarStyle(
          flickDistanceThreshold: other.flickDistanceThreshold,
        ),
        'flickMaxDuration': CalendarStyle(
          flickMaxDuration: other.flickMaxDuration,
        ),
        'dragBoxSizePercentage': CalendarStyle(
          dragBoxSizePercentage: other.dragBoxSizePercentage,
        ),
        'dragProgressThreshold': CalendarStyle(
          dragProgressThreshold: other.dragProgressThreshold,
        ),
      };

      expect(differInOneField, hasLength(27));
      for (final MapEntry(key: field, value: style)
          in differInOneField.entries) {
        expect(style, isNot(equals(const CalendarStyle())), reason: field);
      }
    });
  });
}
