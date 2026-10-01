import 'package:flip_calendar/flip_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarDayData', () {
    /// New data for June 15, 2024, with the given fields changed.
    CalendarDayData data({
      DateTime? date,
      bool isCurrentMonth = true,
      bool isToday = false,
      bool isSelected = false,
      bool isFutureDate = false,
      bool isEnabled = true,
      int row = 2,
      int column = 6,
    }) {
      return CalendarDayData(
        date: date ?? DateTime(2024, 6, 15),
        isCurrentMonth: isCurrentMonth,
        isToday: isToday,
        isSelected: isSelected,
        isFutureDate: isFutureDate,
        isEnabled: isEnabled,
        row: row,
        column: column,
      );
    }

    test('data with equal fields are equal and have the same hash code', () {
      final a = data();
      final b = data();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('data that differ in any one field are not equal', () {
      final differInOneField = {
        'date': data(date: DateTime(2024, 6, 16)),
        'isCurrentMonth': data(isCurrentMonth: false),
        'isToday': data(isToday: true),
        'isSelected': data(isSelected: true),
        'isFutureDate': data(isFutureDate: true),
        'isEnabled': data(isEnabled: false),
        'row': data(row: 3),
        'column': data(column: 5),
      };

      expect(differInOneField, hasLength(8));
      for (final MapEntry(key: field, value: other)
          in differInOneField.entries) {
        expect(other, isNot(equals(data())), reason: field);
      }
    });

    test('toString names every field with its value', () {
      expect(
        data(isToday: true).toString(),
        equals(
          'CalendarDayData(date: 2024-06-15 00:00:00.000, '
          'isCurrentMonth: true, isToday: true, isSelected: false, '
          'isFutureDate: false, isEnabled: true, row: 2, column: 6)',
        ),
      );
    });
  });
}
