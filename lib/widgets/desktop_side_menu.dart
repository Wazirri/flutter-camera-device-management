import 'package:flutter/material.dart';
import 'package:camera_device_manager/theme/app_theme.dart';
import 'package:camera_device_manager/models/menu_item.dart';

class DesktopSideMenu extends StatelessWidget {
  final String currentRoute;
  final Function(String) onDestinationSelected;

  const DesktopSideMenu({
    Key? key,
    required this.currentRoute,
    required this.onDestinationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppTheme.darkAppBarColor,
      child: Column(
        children: [
          // Header with logo and app name
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                // Logo
                Icon(
                  Icons.camera_alt,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 12),
                // App title
                const Text(
                  'Camera Manager',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          
          // Navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(
                  context,
                  MenuItemData(
                    route: '/dashboard',
                    title: 'Dashboard',
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard,
                  ),
                ),
                _buildNavItem(
                  context,
                  MenuItemData(
                    route: '/cameras',
                    title: 'Cameras',
                    icon: Icons.camera_outlined,
                    activeIcon: Icons.camera,
                  ),
                ),
                _buildNavItem(
                  context,
                  MenuItemData(
                    route: '/multi-live-view',
                    title: 'Multi-View',
                    icon: Icons.grid_view_outlined,
                    activeIcon: Icons.grid_view,
                  ),
                ),
                _buildNavItem(
                  context,
                  MenuItemData(
                    route: '/camera-devices',
                    title: 'Camera Devices',
                    icon: Icons.videocam_outlined,
                    activeIcon: Icons.videocam,
                  ),
                ),
                _buildNavItem(
                  context,
                  MenuItemData(
                    route: '/devices',
                    title: 'Devices',
                    icon: Icons.devices_outlined,
                    activeIcon: Icons.devices,
                  ),
                ),
                const Divider(color: Colors.white24),
                _buildNavItem(
                  context,
                  MenuItemData(
                    route: '/settings',
                    title: 'Settings',
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                  ),
                ),
              ],
            ),
          ),
          
          // Footer with version info or user info
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, MenuItemData item) {
    final isActive = currentRoute == item.route;
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onDestinationSelected(item.route),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isActive ? AppTheme.primaryColor.withOpacity(0.2) : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive ? AppTheme.primaryColor : Colors.white70,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  item.title,
                  style: TextStyle(
                    color: isActive ? AppTheme.primaryColor : Colors.white70,
                    fontSize: 16,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
