import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MobileBottomNavigationBar extends StatelessWidget {
  final String currentRoute;
  final Function(String) onDestinationSelected;

  const MobileBottomNavigationBar({
    Key? key,
    required this.currentRoute,
    required this.onDestinationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: AppTheme.darkSurface,
      selectedItemColor: AppTheme.accentColor,
      unselectedItemColor: AppTheme.darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      currentIndex: _getSelectedIndex(),
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.videocam),
          label: 'Live View',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.video_library),
          label: 'Recordings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.devices),
          label: 'Camera Devices',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  int _getSelectedIndex() {
    switch (currentRoute) {
      case '/dashboard':
        return 0;
      case '/live-view':
        return 1;
      case '/recordings':
        return 2;
      case '/camera-devices':
        return 3;
      case '/settings':
        return 4;
      default:
        return 0;
    }
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        onDestinationSelected('/dashboard');
        break;
      case 1:
        onDestinationSelected('/live-view');
        break;
      case 2:
        onDestinationSelected('/recordings');
        break;
      case 3:
        onDestinationSelected('/camera-devices');
        break;
      case 4:
        onDestinationSelected('/settings');
        break;
    }
  }
}