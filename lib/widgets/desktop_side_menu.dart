import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/cameras_screen.dart';
import '../screens/camera_devices_screen.dart';
import '../screens/live_view_screen.dart';
import '../screens/record_view_screen.dart';
import '../theme/app_theme.dart';

class DesktopSideMenu extends StatelessWidget {
  final String currentRoute;
  
  const DesktopSideMenu({
    Key? key,
    required this.currentRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: _getSelectedIndex(),
      onDestinationSelected: (int index) {
        _onDestinationSelected(context, index);
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
      case DashboardScreen.routeName:
        return 0;
      case CamerasScreen.routeName:
        return 1;
      case CameraDevicesScreen.routeName:
        return 2;
      case LiveViewScreen.routeName:
        return 3;
      case RecordViewScreen.routeName:
        return 4;
      default:
        return 0;
    }
  }

  void _onDestinationSelected(BuildContext context, int index) {
    String route;
    switch (index) {
      case 0:
        route = DashboardScreen.routeName;
        break;
      case 1:
        route = CamerasScreen.routeName;
        break;
      case 2:
        route = CameraDevicesScreen.routeName;
        break;
      case 3:
        route = LiveViewScreen.routeName;
        break;
      case 4:
        route = RecordViewScreen.routeName;
        break;
      default:
        route = DashboardScreen.routeName;
    }
    
    if (route != currentRoute) {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }
}
