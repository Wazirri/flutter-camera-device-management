import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/cameras_screen.dart';
import '../screens/camera_devices_screen.dart';
import '../screens/live_view_screen.dart';
import '../screens/record_view_screen.dart';
import '../theme/app_theme.dart';

class MobileBottomNavigationBar extends StatelessWidget {
  final String currentRoute;
  
  const MobileBottomNavigationBar({
    Key? key,
    required this.currentRoute,
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

  void _onItemTapped(BuildContext context, int index) {
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
