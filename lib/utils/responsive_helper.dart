import 'package:flutter/material.dart';

enum DeviceType {
  mobile,
  tablet,
  desktop,
}

class ResponsiveHelper {
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < 600) {
      return DeviceType.mobile;
    } else if (width < 1200) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }
  
  static bool isMobile(BuildContext context) {
    return getDeviceType(context) == DeviceType.mobile;
  }
  
  static bool isTablet(BuildContext context) {
    return getDeviceType(context) == DeviceType.tablet;
  }
  
  static bool isDesktop(BuildContext context) {
    return getDeviceType(context) == DeviceType.desktop;
  }
  
  static double getGridViewCrossAxisCount(BuildContext context) {
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
  
  static double getGridViewChildAspectRatio(BuildContext context) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return 16 / 10; // Wider cards on mobile
      case DeviceType.tablet:
        return 16 / 9; // Standard aspect ratio for tablets
      case DeviceType.desktop:
        return 16 / 9; // Standard aspect ratio for desktops
    }
  }
  
  static EdgeInsets getPagePadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return const EdgeInsets.all(8.0);
      case DeviceType.tablet:
        return const EdgeInsets.all(16.0);
      case DeviceType.desktop:
        return const EdgeInsets.all(24.0);
    }
  }
  
  static EdgeInsets getCardPadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0);
      case DeviceType.tablet:
        return const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0);
      case DeviceType.desktop:
        return const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0);
    }
  }
}