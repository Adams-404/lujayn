/// The spacing scale every Lujayn surface uses.
///
/// Values are multiples of four so alignment stays consistent across screens
/// and at large text sizes. Reach for these instead of literal padding: an
/// arbitrary `EdgeInsets.all(17)` is how a design system quietly falls apart.
abstract final class AppSpacing {
  /// 4 — hairline separation between a label and its value.
  static const double xxs = 4;

  /// 8 — the default gap between closely related elements.
  static const double xs = 8;

  /// 12 — gap between a control and its supporting text.
  static const double sm = 12;

  /// 16 — default gap inside a grouped surface.
  static const double md = 16;

  /// 20 — gap between sibling blocks.
  static const double lg = 20;

  /// 24 — screen gutter and section separation.
  static const double xl = 24;

  /// 32 — separation before a primary action.
  static const double xxl = 32;

  /// 40 — breathing room around a full-screen state.
  static const double xxxl = 40;

  /// The horizontal gutter used by scrolling screens.
  static const double gutter = 22;

  /// Space reserved so a floating action button never covers the last row.
  static const double fabClearance = 96;

  /// Minimum Android touch target.
  static const double minTouchTarget = 48;
}

/// Corner radii. Lujayn rounds deliberately, not universally.
abstract final class AppRadius {
  /// 10 — inputs and buttons.
  static const double control = 10;

  /// 14 — bordered surfaces such as cards and panels.
  static const double surface = 14;

  /// 24 — circular affordances such as the caller badge.
  static const double circle = 24;
}
