import 'package:flutter/widgets.dart';

/// The two layouts every screen supports. Web, Android and iOS share one UI;
/// the window width (not the platform) picks the layout, so a phone browser
/// gets the phone layout and a tablet or desktop window gets the wide one.
enum AikoLayout {
  /// Phones and narrow windows: bottom tab bar, bottom sheets, full-screen
  /// pages.
  compact,

  /// Tablets, laptops and desktop browsers: sidebar, centered content
  /// columns, dialogs instead of bottom sheets and full-screen pages.
  expanded,
}

abstract final class AikoBreakpoints {
  /// From this width the app uses [AikoLayout.expanded].
  static const double expanded = 840;

  /// From this width the sidebar shows labels and sections.
  static const double labeledSidebar = 1200;

  /// From this content width the Overview shows two columns.
  static const double twoColumnContent = 960;

  static AikoLayout layoutFor(double width) =>
      width >= expanded ? AikoLayout.expanded : AikoLayout.compact;

  static AikoLayout of(BuildContext context) =>
      layoutFor(MediaQuery.sizeOf(context).width);

  static bool isExpanded(BuildContext context) =>
      of(context) == AikoLayout.expanded;

  /// Maximum width of a routed page's content column in the expanded layout,
  /// so text and lists don't stretch across a wide monitor.
  static double contentWidthFor(String path) {
    if (path.startsWith('/home')) return 1320;
    if (path.startsWith('/aiko')) return 960;
    // Exact match: tools nested under these paths (such as
    // /settings/chance-of-success) keep the regular width.
    if (_narrowPages.contains(path)) return 880;
    return 1120;
  }

  static const _narrowPages = {
    '/settings',
    '/profile',
    '/connect-line',
    '/notifications',
    '/export',
    '/transaction-rules',
    '/transaction-capture',
  };
}
