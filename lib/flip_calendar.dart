/// A customizable month calendar widget with page-turn animations
/// and swipe gesture navigation.
///
/// [PageTurnEdge] and [PageTurnStyle], which [FlipCalendar.boundEdge] and
/// [CalendarStyle.pageTurnStyle] take, come from `page_turn_animation` and
/// are exported here, so this import is the only one needed:
///
/// ```dart
/// import 'package:flip_calendar/flip_calendar.dart';
/// ```
///
/// @docImport 'package:page_turn_animation/page_turn_animation.dart';
/// @docImport 'src/calendar/flip_calendar.dart';
/// @docImport 'src/style/calendar_style.dart';
library;

// The page_turn_animation types this package's API takes
export 'package:page_turn_animation/page_turn_animation.dart'
    show PageTurnEdge, PageTurnStyle;

// Animation
export 'src/animation/multi_month_animation_mode.dart';
export 'src/calendar/calendar_controller.dart' hide ControlledCalendar;
export 'src/calendar/calendar_day_data.dart';
// Core
export 'src/calendar/flip_calendar.dart';
// Style
export 'src/style/calendar_style.dart';
// Utils
export 'src/utils/date_constraint.dart';
export 'src/utils/month_grid.dart';
