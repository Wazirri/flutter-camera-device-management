import 'package:flutter/material.dart';

class ResponsiveHelper {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 800;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  // Helper methods for responsive padding and margin
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24.0);
    } else {
      return const EdgeInsets.all(32.0);
    }
  }

  static EdgeInsets getResponsiveHorizontalPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 16.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32.0);
    } else {
      return const EdgeInsets.symmetric(horizontal: 48.0);
    }
  }

  // Helper methods for responsive font sizes
  static double getHeadingFontSize(BuildContext context) {
    if (isMobile(context)) {
      return 22.0;
    } else if (isTablet(context)) {
      return 24.0;
    } else {
      return 28.0;
    }
  }

  static double getSubheadingFontSize(BuildContext context) {
    if (isMobile(context)) {
      return 18.0;
    } else if (isTablet(context)) {
      return 20.0;
    } else {
      return 22.0;
    }
  }

  static double getBodyFontSize(BuildContext context) {
    if (isMobile(context)) {
      return 14.0;
    } else if (isTablet(context)) {
      return 15.0;
    } else {
      return 16.0;
    }
  }

  // Helper methods for grid layouts
  static int getCrossAxisCount(BuildContext context) {
    if (isMobile(context)) {
      return 1;
    } else if (isTablet(context)) {
      return 2;
    } else {
      final width = MediaQuery.of(context).size.width;
      if (width > 1600) {
        return 4;
      } else {
        return 3;
      }
    }
  }
  
  static int getCameraGridCount(BuildContext context) {
    if (isMobile(context)) {
      return 1;
    } else if (isTablet(context)) {
      return 2;
    } else {
      final width = MediaQuery.of(context).size.width;
      if (width > 1600) {
        return 4;
      } else {
        return 3;
      }
    }
  }
}
