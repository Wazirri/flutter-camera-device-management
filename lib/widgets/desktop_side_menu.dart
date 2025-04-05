import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DesktopSideMenu extends StatelessWidget {
  final String currentRoute;
  final Function(String)? onDestinationSelected;
  
  const DesktopSideMenu({
    Key? key,
    required this.currentRoute,
    this.onDestinationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: _getSelectedIndex(),
      onDestinationSelected: (int index) {
        // If onDestinationSelected callback is provided, use it
        if (onDestinationSelected != null) {
          final route = _getRouteForIndex(index);
          onDestinationSelected!(route);
        } else {
          // Otherwise use the default implementation
          _onDestinationSelectedInternal(context, index);
        }
      },
      backgroundColor: AppTheme.panelBackground,
      labelType: NavigationRailLabelType.selected,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.videocam_outlined),
          selectedIcon: Icon(Icons.videocam),
          label: Text('Cameras'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.devices_outlined),
          selectedIcon: Icon(Icons.devices),
          label: Text('Devices'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.live_tv_outlined),
          selectedIcon: Icon(Icons.live_tv),
          label: Text('Live View'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.video_library_outlined),
          selectedIcon: Icon(Icons.video_library),
          label: Text('Records'),
        ),
      ],
      selectedIconTheme: IconThemeData(
        color: AppTheme.primaryColor,
      ),
      unselectedIconTheme: const IconThemeData(
        color: Colors.white70,
      ),
      selectedLabelTextStyle: TextStyle(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.bold,
      ),
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

  String _getRouteForIndex(int index) {
    switch (index) {
      case 0:
        return '/dashboard';
      case 1:
        return '/cameras';
      case 2:
        return '/camera-devices';
      case 3:
        return '/live-view';
      case 4:
        return '/recordings';
      default:
        return '/dashboard';
    }
  }

  void _onDestinationSelectedInternal(BuildContext context, int index) {
    String route = _getRouteForIndex(index);
    
    if (route != currentRoute) {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }
}
