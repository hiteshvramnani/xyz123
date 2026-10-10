import 'package:flutter/animation.dart';

/// Motion tokens. Durations are deliberately short — this is an operator
/// utility, motion should confirm state and transitions, never delay a task.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

abstract final class AppCurves {
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve emphasized = Curves.easeOutCubic;
}
