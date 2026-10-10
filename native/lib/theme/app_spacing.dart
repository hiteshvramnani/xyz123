import 'package:flutter/widgets.dart';

/// Spacing scale — a single 4-based rhythm used everywhere instead of
/// scattered magic numbers. Use these for padding, margins and gaps.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Common edge insets, pre-built to keep call sites terse and consistent.
  static const EdgeInsets screen = EdgeInsets.all(lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);

  // Ready-made vertical gaps.
  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);

  // Ready-made horizontal gaps.
  static const SizedBox gapHSm = SizedBox(width: sm);
  static const SizedBox gapHMd = SizedBox(width: md);
}

/// Corner radii — standardised to three professional steps (previously
/// 6/8/10/12/18 were mixed arbitrarily). Restrained, not bubbly.
abstract final class AppRadii {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double pill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sheet =
      BorderRadius.vertical(top: Radius.circular(lg));
}

/// Icon sizing tokens.
abstract final class AppIconSize {
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 40;
}

/// Minimum interactive target, per accessibility guidance.
abstract final class AppSizes {
  static const double minTouchTarget = 48;
  static const double buttonHeight = 48;
  static const double thumbnail = 100;
}
