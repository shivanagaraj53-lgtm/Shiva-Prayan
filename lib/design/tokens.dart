import 'package:flutter/widgets.dart';

/// Design tokens for Prayan.
///
/// Every spacing, radius, duration and elevation in the app comes from here.
/// Hard-coded magic numbers in widgets are what make a product look assembled
/// rather than designed — the brief calls out "inconsistent radii and random
/// shadows" as things to avoid (§36).
class Spacing {
  const Spacing._();

  /// 4pt base grid. Everything is a multiple of it.
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Standard horizontal page inset.
  static const double page = 20;

  /// Vertical rhythm between major sections.
  static const double section = 28;

  /// Bottom padding that clears the navigation bar and the quick-log button.
  static const double scrollBottom = 120;
}

class Radii {
  const Radii._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;

  /// The default for cards and sheets. One radius used almost everywhere is
  /// what reads as "designed".
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
}

/// Motion timings.
///
/// Fast and subtle by instruction (§25): nothing here is long enough to make
/// the app feel like it is performing for the user. Every animation in the app
/// must also respect [MediaQuery.disableAnimations]; see [Motion.duration].
class Motion {
  const Motion._();

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);

  /// Reserved for the splash reveal and the score-change explanation, the only
  /// two places a longer beat is earned.
  static const Duration deliberate = Duration(milliseconds: 620);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasis = Curves.easeInOutCubic;

  /// Collapses a duration to zero when the platform asks for reduced motion.
  ///
  /// Call this instead of using a constant directly, so accessibility is the
  /// default rather than something each widget remembers to handle (§2).
  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
          ? Duration.zero
          : value;
}

/// Touch target sizes. 48dp minimum per both platforms' accessibility guidance.
class Sizes {
  const Sizes._();

  static const double minTouchTarget = 48;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double avatar = 40;

  /// The discipline ring on the dashboard.
  static const double scoreRing = 132;
  static const double scoreRingCompact = 72;

  static const double navBarHeight = 64;
  static const double cardMinHeight = 88;
}

/// Named durations for skeleton shimmer and other loading affordances.
class Loading {
  const Loading._();

  static const Duration shimmerPeriod = Duration(milliseconds: 1400);

  /// Below this, showing a spinner reads as a flicker — render the previous
  /// state instead.
  static const Duration spinnerThreshold = Duration(milliseconds: 300);
}
