import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DesktopSideMenu extends StatelessWidget {
  final String currentRoute;
  final Function(String) onDestinationSelected;

  const DesktopSideMenu({
    super.key,
    required this.currentRoute,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppTheme.darkSurface,
      child: Column(
        children: [
          // App logo and title
          Container(
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/app_logo.png',
                  width: 60,
                  height: 60,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.video_camera_back,
                      size: 60,
                      color: AppTheme.primaryColor,
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Camera Device Manager',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  context,
                  'Dashboard',
                  Icons.dashboard,
                  '/dashboard',
                ),
                _buildMenuItem(
                  context,
                  'Live View',
                  Icons.videocam,
                  '/live-view',
                ),
                _buildMenuItem(
                  context,
                  'Recordings',
                  Icons.video_library,
                  '/recordings',
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                  child: Text(
                    'DEVICES',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkTextSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildMenuItem(
                  context,
                  'Camera Devices',
                  Icons.devices,
                  '/camera-devices',
                ),
                _buildMenuItem(
                  context,
                  'Cameras',
                  Icons.camera,
                  '/cameras',
                ),
                _buildMenuItem(
                  context,
                  'Devices',
                  Icons.device_hub,
                  '/devices',
                ),
                const Divider(height: 1),
                _buildMenuItem(
                  context,
                  'Settings',
                  Icons.settings,
                  '/settings',
                ),
                _buildMenuItem(
                  context,
                  'WebSocket Logs',
                  Icons.feed,
                  '/websocket-logs',
                ),
              ],
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    String route,
  ) {
    final isSelected = currentRoute == route;
    
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppTheme.accentColor.withOpacity(0.15),
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.accentColor : AppTheme.darkTextSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.accentColor : AppTheme.darkTextPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () => onDestinationSelected(route),
    );
  }
}