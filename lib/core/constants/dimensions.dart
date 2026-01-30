import 'package:flutter/material.dart';

/// BODA CONNECT Design Tokens - Spacing & Dimensions
/// Based on Figma specifications:
/// Grid: 8pt system
/// Safe padding: 16px
/// Radius: Cards 12px | Buttons 10px
class AppDimensions {
  AppDimensions._();

  // Breakpoints for responsive design
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;

  // Base spacing unit (8pt grid)
  static const double unit = 8;

  // Spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  // Padding
  static const double paddingXs = 8;
  static const double paddingSm = 12;
  static const double paddingMd = 16;
  static const double paddingLg = 20;
  static const double paddingXl = 24;
  static const double paddingXxl = 32;

  // Screen padding (safe area)
  static const double screenPadding = 16;
  static const double screenPaddingHorizontal = 22;

  // Border Radius
  static const double radiusXs = 6;
  static const double radiusSm = 8;
  static const double radiusMd = 10;
  static const double radiusLg = 12;
  static const double radiusXl = 14;
  static const double radiusXxl = 16;
  static const double radiusFull = 999;

  // Component specific
  static const double buttonRadius = 14;
  static const double cardRadius = 16;
  static const double inputRadius = 12;
  static const double chipRadius = 20;

  // Heights
  static const double buttonHeight = 52;
  static const double buttonHeightSmall = 44;
  static const double inputHeight = 52;
  static const double appBarHeight = 56;
  static const double bottomNavHeight = 80;
  static const double bottomSheetRadius = 24;

  // Icon sizes
  static const double iconXs = 16;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 28;
  static const double iconXl = 32;
  static const double iconXxl = 48;

  // Avatar sizes
  static const double avatarSm = 32;
  static const double avatarMd = 42;
  static const double avatarLg = 56;
  static const double avatarXl = 72;
  static const double avatarXxl = 88;

  // Card sizes
  static const double cardMinHeight = 80;
  static const double categoryCardSize = 100;

  // Progress bar
  static const double progressHeight = 4;

  // Animation durations (ms)
  static const int animationFast = 150;
  static const int animationNormal = 200;
  static const int animationSlow = 300;

  // Max content widths for responsive layouts
  static const double maxContentWidthMobile = 600;
  static const double maxContentWidthTablet = 800;
  static const double maxContentWidthDesktop = 1200;

  /// Get responsive horizontal padding based on screen width
  static double getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 16;
    if (width < mobileBreakpoint) return screenPaddingHorizontal;
    if (width < tabletBreakpoint) return 32;
    return 48;
  }

  /// Get responsive grid column count
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 1;
    if (width < mobileBreakpoint) return 2;
    if (width < 900) return 3;
    if (width < tabletBreakpoint) return 4;
    return 5;
  }

  /// Get stats grid columns
  static int getStatsGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 1;
    if (width < mobileBreakpoint) return 2;
    if (width < 900) return 3;
    return 4;
  }

  /// Get max content width for centered layouts
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return width;
    if (width < tabletBreakpoint) return maxContentWidthTablet;
    return maxContentWidthDesktop;
  }

  /// Check if screen is wide (tablet or desktop)
  static bool isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }

  /// Check if screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Check if screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }
}
