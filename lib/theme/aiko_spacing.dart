/// Spacing tokens based on the 8 px grid defined in DESIGN.md.
///
/// Usage:
/// ```dart
/// Padding(padding: EdgeInsets.all(AikoSpacing.md))
/// SizedBox(height: AikoSpacing.sm)
/// ```
class AikoSpacing {
  const AikoSpacing._();

  /// 4 px — icon/text gaps, tight metadata.
  static const double xs = 4;

  /// 8 px — compact rows, chips.
  static const double sm = 8;

  /// 16 px — screen padding, form gaps.
  static const double md = 16;

  /// 24 px — card groups, major sections.
  static const double lg = 24;

  /// 32 px — top-level screen rhythm.
  static const double xl = 32;
}
