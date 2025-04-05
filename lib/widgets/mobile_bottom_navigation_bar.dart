import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MobileBottomNavigationBar extends StatelessWidget {
  final String currentRoute;
  final Function(String)? onDestinationSelected;
  
  const MobileBottomNavigationBar({
    Key? key,
    required this.currentRoute,
    this.onDestinationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _getSelectedIndex(),
      onTap: (index) => _onItemTapped(context, index),
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppTheme.surfaceColor,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: Colors.white70,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.videocam_outlined),
          activeIcon: Icon(Icons.videocam),
          label: 'Cameras',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.devices_outlined),
          activeIcon: Icon(Icons.devices),
          label: 'Devices',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.live_tv_outlined),
          activeIcon: Icon(Icons.live_tv),
          label: 'Live View',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.video_library_outlined),
          activeIcon: Icon(Icons.video_library),
          label: 'Records',
        ),
      ],
    );
  }

  int _getSelectedIndex() {
    switch (currentRoute) {
      case '/dashboard':
        return 0;
      case '/cameras':
        return 1;
      case '/camera-devices':
        return 2;
      case '/live-view':
        return 3;
      case '/recordings':
        return 4;
      default:
        return 0;
    }
  }

  void _onItemTapped(BuildContext context, int index) {
    String route;
    switch (index) {
      case 0:
        route = '/dashboard';
        break;
      case 1:
        route = '/cameras';
        break;
      case 2:
        route = '/camera-devices';
        break;
      case 3:
        route = '/live-view';
        break;
      case 4:
        route = '/recordings';
        break;
      default:
        route = '/dashboard';
    }
    
    // If onDestinationSelected callback is provided, use it
    if (onDestinationSelected != null) {
      onDestinationSelected!(route);
    } else {
      // Otherwise use the default implementation
      if (route != currentRoute) {
        Navigator.of(context).pushReplacementNamed(route);
      }
    }
  }
}
