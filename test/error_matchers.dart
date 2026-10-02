import 'package:flutter_test/flutter_test.dart';

/// Matches an [ArgumentError] with this [name], [message] and [invalidValue].
///
/// The fields are compared as values, not as the error's text, because Dart
/// renders an invalid value such as a list differently on each platform.
Matcher argumentErrorWith(String name, String message, Object? invalidValue) {
  return isA<ArgumentError>()
      .having((error) => error.name, 'name', name)
      .having((error) => error.message, 'message', message)
      .having((error) => error.invalidValue, 'invalidValue', invalidValue);
}

/// Matches a [RangeError] for [name] with this [invalidValue], the range
/// [start] to [end] (null for no limit on that side), and [message].
Matcher rangeErrorWith(
  String name,
  Object? invalidValue, {
  num? start,
  num? end,
  String message = 'Invalid value',
}) {
  return isA<RangeError>()
      .having((error) => error.name, 'name', name)
      .having((error) => error.invalidValue, 'invalidValue', invalidValue)
      .having((error) => error.start, 'start', start)
      .having((error) => error.end, 'end', end)
      .having((error) => error.message, 'message', message);
}
