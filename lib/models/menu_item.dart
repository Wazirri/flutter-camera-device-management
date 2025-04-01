import 'package:flutter/material.dart';

class AppMenuItem {
  final String id;
  final String title;
  final IconData icon;
  final String route;
  
  const AppMenuItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.route,
  });
}

// List of menu items for the application
class AppMenuItems {
  static const List<AppMenuItem> items = [
    AppMenuItem(
      id: 'dashboard',
      title: 'Dashboard',
      icon: Icons.dashboard,
      route: '/dashboard',
    ),
    AppMenuItem(
      id: 'live_view',
      title: 'Live View',
      icon: Icons.videocam,
      route: '/live_view',
    ),
    AppMenuItem(
      id: 'record_view',
      title: 'Record View',
      icon: Icons.video_library,
      route: '/record_view',
    ),
    AppMenuItem(
      id: 'cameras',
      title: 'Cameras',
      icon: Icons.camera_alt,
      route: '/cameras',
    ),
    AppMenuItem(
      id: 'devices',
      title: 'Devices',
      icon: Icons.devices,
      route: '/devices',
    ),
    AppMenuItem(
      id: 'settings',
      title: 'Settings',
      icon: Icons.settings,
      route: '/settings',
    ),
  ];
}
