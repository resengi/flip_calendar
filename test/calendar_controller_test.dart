import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarController', () {
    test('initializes with current month when no initial month provided', () {
      final controller = CalendarController();
      final now = DateTime.now();

      expect(controller.currentMonth.year, equals(now.year));
      expect(controller.currentMonth.month, equals(now.month));
      expect(controller.currentMonth.day, equals(1));

      controller.dispose();
    });

    test('initializes with provided month (normalized)', () {
      final controller = CalendarController(
        initialMonth: DateTime(2024, 6, 15),
      );
      expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
      controller.dispose();
    });

    test('normalizes initial month to first day at midnight', () {
      final controller = CalendarController(
        initialMonth: DateTime(2024, 3, 25, 14, 30),
      );
      expect(controller.currentMonth, equals(DateTime(2024, 3, 1)));
      controller.dispose();
    });

    test('goToMonth updates and notifies', () {
      final controller = CalendarController(initialMonth: DateTime(2024, 1, 1));
      var notified = false;
      controller.addListener(() => notified = true);

      controller.goToMonth(DateTime(2024, 6, 15));

      expect(controller.currentMonth, equals(DateTime(2024, 6, 1)));
      expect(notified, isTrue);

      controller.dispose();
    });

    test('goToMonth is no-op for same month', () {
      final controller = CalendarController(initialMonth: DateTime(2024, 6, 1));
      var notified = false;
      controller.addListener(() => notified = true);

      controller.goToMonth(DateTime(2024, 6, 15));

      expect(notified, isFalse);

      controller.dispose();
    });

    test('nextMonth advances correctly', () {
      final controller = CalendarController(initialMonth: DateTime(2024, 6, 1));
      controller.nextMonth();
      expect(controller.currentMonth, equals(DateTime(2024, 7, 1)));
      controller.dispose();
    });

    test('nextMonth handles year boundary', () {
      final controller = CalendarController(
        initialMonth: DateTime(2024, 12, 1),
      );
      controller.nextMonth();
      expect(controller.currentMonth, equals(DateTime(2025, 1, 1)));
      controller.dispose();
    });

    test('previousMonth goes back correctly', () {
      final controller = CalendarController(initialMonth: DateTime(2024, 6, 1));
      controller.previousMonth();
      expect(controller.currentMonth, equals(DateTime(2024, 5, 1)));
      controller.dispose();
    });

    test('previousMonth handles year boundary', () {
      final controller = CalendarController(initialMonth: DateTime(2024, 1, 1));
      controller.previousMonth();
      expect(controller.currentMonth, equals(DateTime(2023, 12, 1)));
      controller.dispose();
    });

    test('goToToday navigates to current month', () {
      final controller = CalendarController(initialMonth: DateTime(2020, 1, 1));
      controller.goToToday();
      final now = DateTime.now();
      expect(controller.currentMonth.year, equals(now.year));
      expect(controller.currentMonth.month, equals(now.month));
      controller.dispose();
    });

    test('goToYearMonth navigates correctly', () {
      final controller = CalendarController(initialMonth: DateTime(2024, 1, 1));
      controller.goToYearMonth(2025, 8);
      expect(controller.currentMonth, equals(DateTime(2025, 8, 1)));
      controller.dispose();
    });

    test('isAnimating is initially false', () {
      final controller = CalendarController();
      expect(controller.isAnimating, isFalse);
      controller.dispose();
    });

    test('setAnimating updates and notifies', () {
      final controller = CalendarController();
      var notified = false;
      controller.addListener(() => notified = true);

      controller.setAnimating(true);

      expect(controller.isAnimating, isTrue);
      expect(notified, isTrue);

      controller.dispose();
    });

    test('setAnimating does not notify when unchanged', () {
      final controller = CalendarController();
      controller.setAnimating(true);

      var notified = false;
      controller.addListener(() => notified = true);

      controller.setAnimating(true); // Same value
      expect(notified, isFalse);

      controller.dispose();
    });

    test('dispose works without error', () {
      final controller = CalendarController();
      controller.addListener(() {});
      expect(() => controller.dispose(), returnsNormally);
    });
  });
}
