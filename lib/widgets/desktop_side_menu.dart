import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DesktopSideMenu extends StatefulWidget {
  final String currentRoute;
  final Function(String) onDestinationSelected;

  const DesktopSideMenu({
    Key? key,
    required this.currentRoute,
    required this.onDestinationSelected,
  }) : super(key: key);

  @override
  State<DesktopSideMenu> createState() => _DesktopSideMenuState();
}

class _DesktopSideMenuState extends State<DesktopSideMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  
  // Define menu items
  final List<Map<String, dynamic>> _menuItems = [
    {
      'title': 'Dashboard',
      'icon': Icons.dashboard,
      'route': '/dashboard',
    },
    {
      'title': 'Live View',
      'icon': Icons.videocam,
      'route': '/live-view',
    },
    {
      'title': 'Recordings',
      'icon': Icons.video_library,
      'route': '/recordings',
    },
    {
      'title': 'Cameras',
      'icon': Icons.camera,
      'route': '/cameras',
    },
    {
      'title': 'Devices',
      'icon': Icons.devices,
      'route': '/devices',
    },
    {
      'title': 'Camera Devices',
      'icon': Icons.camera_alt,
      'route': '/camera-devices',
    },
    {
      'title': 'Settings',
      'icon': Icons.settings,
      'route': '/settings',
    },
    {
      'title': 'WebSocket Logs',
      'icon': Icons.history,
      'route': '/websocket-logs',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    // Start the animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 250,
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
          right: BorderSide(
            color: AppTheme.primaryColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // App title with logo
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.camera_enhance,
                    color: AppTheme.accentColor,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
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
          ),
          
          const Divider(height: 1),
          
          // Menu items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final isSelected = widget.currentRoute == item['route'];
                
                // Create staggered animation for each menu item
                final animation = CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    0.1 + (index * 0.05),
                    0.6 + (index * 0.05),
                    curve: Curves.easeOut,
                  ),
                );
                
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-0.5, 0.0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: ListTile(
                      leading: Icon(
                        item['icon'],
                        color: isSelected 
                            ? AppTheme.accentColor 
                            : AppTheme.darkTextSecondary,
                      ),
                      title: Text(
                        item['title'],
                        style: TextStyle(
                          color: isSelected 
                              ? AppTheme.accentColor 
                              : AppTheme.darkTextPrimary,
                          fontWeight: isSelected 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: AppTheme.accentColor.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onTap: () => widget.onDestinationSelected(item['route']),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Bottom section with logout and version
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _animationController,
              curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1),
                // Logout button
                ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: AppTheme.darkTextSecondary,
                  ),
                  title: Text(
                    'Logout',
                    style: TextStyle(
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                  onTap: () => widget.onDestinationSelected('/login'),
                ),
                const SizedBox(height: 16),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
