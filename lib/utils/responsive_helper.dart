import 'package:flutter/material.dart';

class ResponsiveHelper {
  // Check if the device is a mobile phone
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }
  
  // Check if the device is a tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }
  
  // Check if the device is a desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }
  
  // Get appropriate grid columns based on screen size
  static int getGridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 600) {
      return 1; // Mobile: 1 column
    } else if (width < 900) {
      return 2; // Small tablet: 2 columns
    } else if (width < 1200) {
      return 3; // Large tablet: 3 columns
    } else if (width < 1800) {
      return 4; // Desktop: 4 columns
    } else {
      return 5; // Large desktop: 5 columns
    }
  }
  
  // Get appropriate item extent (height) based on screen size
  static double getGridItemExtent(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 600) {
      return 180; // Mobile
    } else if (width < 900) {
      return 200; // Small tablet
    } else if (width < 1200) {
      return 220; // Large tablet
    } else {
      return 240; // Desktop
    }
  }
  
  // Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.all(24);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(16);
    } else {
      return const EdgeInsets.all(12);
    }
  }
  
  // Get responsive font size based on screen size
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    if (isDesktop(context)) {
      return baseFontSize * 1.2;
    } else if (isTablet(context)) {
      return baseFontSize * 1.1;
    } else {
      return baseFontSize;
    }
  }
}
