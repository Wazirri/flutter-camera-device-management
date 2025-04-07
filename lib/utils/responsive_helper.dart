import 'package:flutter/material.dart';

class ResponsiveHelper {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // Device type checkers
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  // Screen size utilities
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  // Responsive value based on screen width
  static double value({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;

    // Return the appropriate value based on screen width
    if (width >= desktopBreakpoint) {
      return desktop ?? tablet ?? mobile;
    }
    if (width >= tabletBreakpoint) {
      return tablet ?? mobile;
    }
    return mobile;
  }

  // Get column count for grid layouts based on screen width
  static int getColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width >= desktopBreakpoint) {
      return 4; // 4 columns for desktop
    } else if (width >= tabletBreakpoint) {
      return 3; // 3 columns for tablet
    } else if (width >= mobileBreakpoint) {
      return 2; // 2 columns for large phones
    } else {
      return 1; // 1 column for small phones
    }
  }

  // Get the appropriate padding based on screen size
  static EdgeInsetsGeometry getPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.all(24.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(16.0);
    } else {
      return const EdgeInsets.all(12.0);
    }
  }

  // Determine if we should use expanded or compact UI elements
  static bool useCompactUI(BuildContext context) {
    return MediaQuery.of(context).size.width < 480;
  }

  // Calculate responsive font size
  static double responsiveFontSize(BuildContext context, double baseFontSize) {
    final width = MediaQuery.of(context).size.width;
    
    if (width >= desktopBreakpoint) {
      return baseFontSize * 1.2; // Larger font for desktop
    } else if (width >= tabletBreakpoint) {
      return baseFontSize * 1.1; // Slightly larger for tablet
    } else {
      return baseFontSize; // Base size for mobile
    }
  }
}
