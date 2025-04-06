import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ResponsiveHelper {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // Device type detection
  static bool isMobile(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return width >= tabletBreakpoint;
  }

  // Platform detection
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  
  static bool get isWeb => kIsWeb;

  // Platform-specific UI decisions
  static bool get useMobileLayout => isAndroid || isIOS;
  
  static bool get useDesktopLayout => isMacOS || isWindows || isLinux;

  // Responsive spacing based on screen size
  static double getResponsiveSpacing(BuildContext context, {
    double mobile = 8.0,
    double tablet = 16.0,
    double desktop = 24.0,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  // Responsive font size based on screen size
  static double getResponsiveFontSize(BuildContext context, {
    double mobile = 14.0,
    double tablet = 16.0,
    double desktop = 18.0,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  // Responsive widget based on screen size
  static Widget responsiveWidget({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }

  // Responsive grid item count based on screen size
  static int getResponsiveGridCount(BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 4,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  // Responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context, {
    EdgeInsets mobile = const EdgeInsets.all(8.0),
    EdgeInsets tablet = const EdgeInsets.all(16.0),
    EdgeInsets desktop = const EdgeInsets.all(24.0),
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }
}