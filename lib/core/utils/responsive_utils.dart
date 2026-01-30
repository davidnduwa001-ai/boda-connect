import 'package:flutter/material.dart';

/// Device type based on screen width
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// Screen orientation helper
enum ScreenOrientation {
  portrait,
  landscape,
}

/// Responsive breakpoints matching common device sizes
class Breakpoints {
  Breakpoints._();

  /// Mobile phones (< 600px)
  static const double mobile = 600;

  /// Tablets and small laptops (600px - 1024px)
  static const double tablet = 1024;

  /// Desktop and large screens (> 1024px)
  static const double desktop = 1024;

  /// Large desktop (> 1440px)
  static const double largeDesktop = 1440;
}

/// Responsive utility class for adapting UI to different screen sizes
class ResponsiveUtils {
  final BuildContext context;
  late final Size _screenSize;
  late final double _width;
  late final double _height;
  late final DeviceType _deviceType;
  late final ScreenOrientation _orientation;

  ResponsiveUtils(this.context) {
    _screenSize = MediaQuery.of(context).size;
    _width = _screenSize.width;
    _height = _screenSize.height;
    _deviceType = _calculateDeviceType();
    _orientation = _calculateOrientation();
  }

  /// Get screen width
  double get width => _width;

  /// Get screen height
  double get height => _height;

  /// Get screen size
  Size get screenSize => _screenSize;

  /// Get device type based on screen width
  DeviceType get deviceType => _deviceType;

  /// Get screen orientation
  ScreenOrientation get orientation => _orientation;

  /// Check if device is mobile
  bool get isMobile => _deviceType == DeviceType.mobile;

  /// Check if device is tablet
  bool get isTablet => _deviceType == DeviceType.tablet;

  /// Check if device is desktop
  bool get isDesktop => _deviceType == DeviceType.desktop;

  /// Check if screen is in portrait mode
  bool get isPortrait => _orientation == ScreenOrientation.portrait;

  /// Check if screen is in landscape mode
  bool get isLandscape => _orientation == ScreenOrientation.landscape;

  /// Check if it's a wide screen (tablet or desktop)
  bool get isWideScreen => _width > Breakpoints.mobile;

  /// Check if it's a very wide screen (desktop)
  bool get isVeryWideScreen => _width > Breakpoints.desktop;

  DeviceType _calculateDeviceType() {
    if (_width < Breakpoints.mobile) {
      return DeviceType.mobile;
    } else if (_width < Breakpoints.desktop) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  ScreenOrientation _calculateOrientation() {
    return _width > _height
        ? ScreenOrientation.landscape
        : ScreenOrientation.portrait;
  }

  /// Get responsive value based on device type
  T value<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    switch (_deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  /// Get responsive value with orientation consideration
  T valueWithOrientation<T>({
    required T mobilePortrait,
    T? mobileLandscape,
    T? tabletPortrait,
    T? tabletLandscape,
    T? desktop,
  }) {
    if (isDesktop) {
      return desktop ?? tabletLandscape ?? tabletPortrait ?? mobilePortrait;
    }

    if (isTablet) {
      return isLandscape
          ? (tabletLandscape ?? tabletPortrait ?? mobilePortrait)
          : (tabletPortrait ?? mobilePortrait);
    }

    return isLandscape
        ? (mobileLandscape ?? mobilePortrait)
        : mobilePortrait;
  }

  /// Get number of grid columns based on screen width
  int get gridColumns {
    if (_width < 400) return 1;
    if (_width < Breakpoints.mobile) return 2;
    if (_width < 900) return 3;
    if (_width < Breakpoints.desktop) return 4;
    return 5;
  }

  /// Get number of columns for stats grid
  int get statsGridColumns {
    if (_width < 400) return 1;
    if (_width < Breakpoints.mobile) return 2;
    if (_width < 900) return 3;
    return 4;
  }

  /// Get maximum content width (for centering on large screens)
  double get maxContentWidth {
    if (_width < Breakpoints.mobile) return _width;
    if (_width < Breakpoints.desktop) return 800;
    return 1200;
  }

  /// Get responsive horizontal padding
  double get horizontalPadding {
    if (_width < 400) return 16;
    if (_width < Breakpoints.mobile) return 22;
    if (_width < Breakpoints.desktop) return 32;
    return 48;
  }

  /// Get responsive card width for horizontal lists
  double get cardWidth {
    if (_width < 400) return _width * 0.7;
    if (_width < Breakpoints.mobile) return 200;
    if (_width < Breakpoints.desktop) return 240;
    return 280;
  }

  /// Get responsive category card size
  double get categoryCardSize {
    if (_width < 400) return 70;
    if (_width < Breakpoints.mobile) return 80;
    if (_width < Breakpoints.desktop) return 100;
    return 120;
  }

  /// Get responsive font scale factor
  double get fontScaleFactor {
    if (_width < 350) return 0.85;
    if (_width < 400) return 0.95;
    if (_width < Breakpoints.mobile) return 1.0;
    if (_width < Breakpoints.desktop) return 1.05;
    return 1.1;
  }

  /// Get responsive icon size
  double responsiveIconSize(double baseSize) {
    return baseSize * fontScaleFactor;
  }

  /// Get responsive spacing
  double responsiveSpacing(double baseSpacing) {
    if (_width < 400) return baseSpacing * 0.8;
    if (_width < Breakpoints.mobile) return baseSpacing;
    if (_width < Breakpoints.desktop) return baseSpacing * 1.2;
    return baseSpacing * 1.5;
  }

  /// Calculate responsive width percentage
  double widthPercent(double percent) => _width * (percent / 100);

  /// Calculate responsive height percentage
  double heightPercent(double percent) => _height * (percent / 100);

  /// Get safe area padding
  EdgeInsets get safeAreaPadding => MediaQuery.of(context).padding;

  /// Get bottom safe area height
  double get bottomSafeArea => MediaQuery.of(context).padding.bottom;

  /// Get top safe area height
  double get topSafeArea => MediaQuery.of(context).padding.top;
}

/// Extension on BuildContext for easy access to responsive utilities
extension ResponsiveContext on BuildContext {
  /// Get ResponsiveUtils instance
  ResponsiveUtils get responsive => ResponsiveUtils(this);

  /// Get device type
  DeviceType get deviceType => responsive.deviceType;

  /// Check if device is mobile
  bool get isMobile => responsive.isMobile;

  /// Check if device is tablet
  bool get isTablet => responsive.isTablet;

  /// Check if device is desktop
  bool get isDesktop => responsive.isDesktop;

  /// Check if screen is wide (tablet or desktop)
  bool get isWideScreen => responsive.isWideScreen;

  /// Get screen width
  double get screenWidth => responsive.width;

  /// Get screen height
  double get screenHeight => responsive.height;

  /// Get grid columns
  int get gridColumns => responsive.gridColumns;

  /// Get horizontal padding
  double get horizontalPadding => responsive.horizontalPadding;

  /// Get max content width
  double get maxContentWidth => responsive.maxContentWidth;
}

/// Responsive wrapper widget that provides different layouts based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ResponsiveUtils responsive) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(context, ResponsiveUtils(context));
      },
    );
  }
}

/// Widget that shows different children based on device type
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveUtils(context);

    switch (responsive.deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}

/// Constrained content wrapper for wide screens
class ResponsiveContentWrapper extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool centerContent;

  const ResponsiveContentWrapper({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.centerContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveUtils(context);
    final effectiveMaxWidth = maxWidth ?? responsive.maxContentWidth;

    Widget content = child;

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (responsive.isWideScreen && centerContent) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Responsive grid that automatically adjusts column count
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final double? childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.childAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveUtils(context);

    final columns = responsive.value(
      mobile: mobileColumns ?? 2,
      tablet: tabletColumns ?? 3,
      desktop: desktopColumns ?? 4,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: runSpacing,
        crossAxisSpacing: spacing,
        childAspectRatio: childAspectRatio ?? 1.5,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}
