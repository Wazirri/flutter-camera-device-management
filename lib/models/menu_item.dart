import 'package:flutter/material.dart';

class CustomMenuItem {
  final String title;
  final IconData icon;
  final String route;
  final bool isSelected;

  CustomMenuItem({
    required this.title,
    required this.icon,
    required this.route,
    this.isSelected = false,
  });

  CustomMenuItem copyWith({
    String? title,
    IconData? icon,
    String? route,
    bool? isSelected,
  }) {
    return CustomMenuItem(
      title: title ?? this.title,
      icon: icon ?? this.icon,
      route: route ?? this.route,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

// Define static menu items for both mobile and desktop
class MenuItems {
  static List<CustomMenuItem> getMenuItems({required String currentRoute}) {
    return [
      CustomMenuItem(
        title: 'Dashboard',
        icon: Icons.dashboard_rounded,
        route: '/dashboard',
        isSelected: currentRoute == '/dashboard',
      ),
      CustomMenuItem(
        title: 'Live View',
        icon: Icons.videocam_rounded,
        route: '/live-view',
        isSelected: currentRoute == '/live-view',
      ),
      CustomMenuItem(
        title: 'Recording Download',
        icon: Icons.download_rounded,
        route: '/recording-download',
        isSelected: currentRoute == '/recording-download',
      ),
      CustomMenuItem(
        title: 'Cameras',
        icon: Icons.camera_alt_rounded,
        route: '/cameras',
        isSelected: currentRoute == '/cameras',
      ),
      CustomMenuItem(
        title: 'Devices',
        icon: Icons.devices_rounded,
        route: '/devices',
        isSelected: currentRoute == '/devices',
      ),
      CustomMenuItem(
        title: 'Camera Devices',
        icon: Icons.camera_enhance_rounded,
        route: '/camera-devices',
        isSelected: currentRoute == '/camera-devices',
      ),
      CustomMenuItem(
        title: 'Settings',
        icon: Icons.settings_rounded,
        route: '/settings',
        isSelected: currentRoute == '/settings',
      ),
    ];
  }
}