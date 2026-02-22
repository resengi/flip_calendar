/// A customizable month calendar widget with page-turn animations
/// and swipe gesture navigation.
///
/// To use this package, also import `page_turn_animation` for
/// [PageTurnEdge] and [PageTurnStyle] types.
///
/// ```dart
/// import 'package:flip_calendar/flip_calendar.dart';
/// import 'package:page_turn_animation/page_turn_animation.dart';
/// ```
library;

// Animation
export 'src/animation/multi_month_animation_mode.dart';
export 'src/calendar/calendar_controller.dart';
export 'src/calendar/calendar_day_data.dart';
// Core
export 'src/calendar/flip_calendar.dart';
// Style
export 'src/style/calendar_haptic_type.dart';
export 'src/style/calendar_style.dart';
// Utils
export 'src/utils/date_constraint.dart';
export 'src/utils/month_grid.dart';
