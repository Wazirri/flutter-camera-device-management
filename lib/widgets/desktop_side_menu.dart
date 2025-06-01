import '../providers/websocket_provider_optimized.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' show min;
import '../theme/app_theme.dart';
import '../providers/websocket_provider_optimized.dart';

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
      'title': 'Multi Camera View',
      'icon': Icons.grid_view,
      'route': '/multi-live-view',
    },
    {
      'title': 'Multi Camera Layout',
      'icon': Icons.grid_on,
      'route': '/multi-camera-view',
    },
    {
      'title': 'Recordings',
      'icon': Icons.video_library,
      'route': '/recordings',
    },
    {
      'title': 'Multi Recordings',
      'icon': Icons.video_collection,
      'route': '/multi-recordings',
    },
    {
      'title': 'Cameras',
      'icon': Icons.camera,
      'route': '/cameras',
    },
    {
      'title': 'Camera Groups',
      'icon': Icons.folder,
      'route': '/camera-groups',
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
                  Image.asset(
                    'assets/images/movita_logo.png',
                    height: 36,
                    width: 36,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'movita ECS',
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
                // Menü öğesi sayısı arttığı için interval değerlerini ölçeklendiriyoruz
                final maxMenuItems = _menuItems.length.toDouble();
                final step = 0.9 / maxMenuItems; // 0.9 aralığını öğe sayısına böl (0.1 marj bırak)
                
                final animation = CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    0.1 + (index * step), // Dinamik başlangıç değeri
                    min(0.1 + ((index + 1) * step), 1.0), // Bitiş değeri en fazla 1.0 olabilir
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
                  leading: const Icon(
                    Icons.logout,
                    color: AppTheme.darkTextSecondary,
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                  onTap: () async {
                    try {
                      // First close WebSocket connection
                      final webSocketProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
                      await webSocketProvider.logout();
                      
                      // Then navigate to login
                      widget.onDestinationSelected('/login');
                    } catch (e) {
                      debugPrint('Error during logout: $e');
                      // Fallback to just navigation
                      widget.onDestinationSelected('/login');
                    }
                  },
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
