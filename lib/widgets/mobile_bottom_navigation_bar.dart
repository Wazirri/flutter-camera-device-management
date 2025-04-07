import 'package:flutter/material.dart';
import 'package:camera_device_manager/theme/app_theme.dart';

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
      backgroundColor: AppTheme.darkAppBarColor,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: Colors.white.withOpacity(0.6),
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      type: BottomNavigationBarType.fixed,
      currentIndex: _getCurrentIndex(),
      onTap: (index) => _handleTap(index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_outlined),
          activeIcon: Icon(Icons.camera),
          label: 'Cameras',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_outlined),
          activeIcon: Icon(Icons.grid_view),
          label: 'Multi-View',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.videocam_outlined),
          activeIcon: Icon(Icons.videocam),
          label: 'Devices',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  int _getCurrentIndex() {
    switch (currentRoute) {
      case '/dashboard':
        return 0;
      case '/cameras':
        return 1;
      case '/multi-live-view':
        return 2;
      case '/camera-devices':
      case '/devices':
        return 3;
      case '/settings':
        return 4;
      default:
        return 0;
    }
  }

  void _handleTap(int index) {
    switch (index) {
      case 0:
        onDestinationSelected('/dashboard');
        break;
      case 1:
        onDestinationSelected('/cameras');
        break;
      case 2:
        onDestinationSelected('/multi-live-view');
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
