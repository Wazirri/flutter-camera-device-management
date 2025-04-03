import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MobileBottomNavigationBar extends StatefulWidget {
  final String currentRoute;
  final Function(String) onDestinationSelected;

  const MobileBottomNavigationBar({
    super.key,
    required this.currentRoute,
    required this.onDestinationSelected,
  });

  @override
  State<MobileBottomNavigationBar> createState() => _MobileBottomNavigationBarState();
}

class _MobileBottomNavigationBarState extends State<MobileBottomNavigationBar> {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _getCurrentIndex(),
      onTap: (index) => _onItemTapped(index, context),
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppTheme.darkSurface,
      selectedItemColor: AppTheme.accentColor,
      unselectedItemColor: AppTheme.darkTextSecondary,
      showUnselectedLabels: true,
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
          label: 'Devices',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.menu),
          label: 'More',
        ),
      ],
    );
  }

  int _getCurrentIndex() {
    switch (widget.currentRoute) {
      case '/dashboard':
        return 0;
      case '/live-view':
        return 1;
      case '/recordings':
        return 2;
      case '/camera-devices':
      case '/cameras':
      case '/devices':
        return 3;
      default:
        return 4; // More menu
    }
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        widget.onDestinationSelected('/dashboard');
        break;
      case 1:
        widget.onDestinationSelected('/live-view');
        break;
      case 2:
        widget.onDestinationSelected('/recordings');
        break;
      case 3:
        widget.onDestinationSelected('/camera-devices');
        break;
      case 4:
        // Show a More menu with additional options
        _showMoreMenu(context);
        break;
    }
  }

  void _showMoreMenu(BuildContext context) {
    // Show a bottom sheet with more options
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDestinationSelected('/settings');
                },
              ),
              ListTile(
                leading: const Icon(Icons.feed),
                title: const Text('WebSocket Logs'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDestinationSelected('/websocket-logs');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDestinationSelected('/login');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}