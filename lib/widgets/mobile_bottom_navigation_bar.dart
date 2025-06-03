import '../providers/websocket_provider_optimized.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class _MobileBottomNavigationBarState extends State<MobileBottomNavigationBar> with SingleTickerProviderStateMixin {
  // Animation controller for smoother transitions
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int _lastIndex = 0;
  
  @override
  void initState() {
    super.initState();
    
    _lastIndex = _getCurrentIndex();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    // Start entrance animation
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 0,
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: AppTheme.accentColor.withOpacity(0.3), // Custom splash color
              highlightColor: AppTheme.accentColor.withOpacity(0.1), // Custom highlight color
            ),
            child: BottomNavigationBar(
              currentIndex: _getCurrentIndex(),
              onTap: (index) => _onItemTapped(index, context),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: AppTheme.accentColor,
              unselectedItemColor: AppTheme.darkTextSecondary,
              showUnselectedLabels: true,
              elevation: 0, // No extra elevation
              items: [
                _buildNavItem(Icons.dashboard, 'Dashboard', 0),
                _buildNavItem(Icons.videocam, 'Live View', 1),
                _buildNavItem(Icons.video_library, 'Recordings', 2),
                _buildNavItem(Icons.devices, 'Devices', 3),
                _buildNavItem(Icons.menu, 'More', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _getCurrentIndex() == index;
    
    // Create a custom animation for each item
    return BottomNavigationBarItem(
      icon: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.8, end: isSelected ? 1.0 : 0.8),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Icon(icon),
          );
        },
      ),
      label: label,
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
    // Don't trigger for the same index
    if (index == _getCurrentIndex()) return;
    
    // Add transition animation when changing tabs
    _animationController.reverse().then((_) {
      setState(() {
        _lastIndex = index;
      });
      
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
      
      _animationController.forward();
    });
  }

  void _showMoreMenu(BuildContext context) {
    // Show a bottom sheet with more options and animations
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 0,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Handle indicator
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 8, bottom: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'More Options',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkTextPrimary,
                      ),
                    ),
                  ),
                ),
                
                // Menu items with staggered animation
                _buildAnimatedMoreMenuItem(
                  context,
                  Icon(Icons.grid_view, color: AppTheme.accentColor),
                  'Multi Camera View',
                  '/multi-live-view',
                  0,
                ),
                
                _buildAnimatedMoreMenuItem(
                  context,
                  Icon(Icons.grid_on, color: AppTheme.accentColor),
                  'Multi Camera Layout',
                  '/multi-camera-view',
                  1,
                ),
                
                _buildAnimatedMoreMenuItem(
                  context,
                  Icon(Icons.video_collection, color: AppTheme.accentColor),
                  'Multi Recordings',
                  '/multi-recordings',
                  2,
                ),

                _buildAnimatedMoreMenuItem(
                  context,
                  Icon(Icons.settings, color: AppTheme.primaryColor),
                  'Settings',
                  '/settings',
                  3,
                ),
                
                _buildAnimatedMoreMenuItem(
                  context,
                  Icon(Icons.feed, color: AppTheme.accentColor),
                  'WebSocket Logs',
                  '/websocket-logs',
                  4,
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(height: 1),
                ),
                
                _buildAnimatedMoreMenuItem(
                  context,
                  const Icon(Icons.logout, color: Colors.red),
                  'Logout',
                  '/login',
                  5,
                  textColor: Colors.red,
                ),
                
                // Add extra padding at the bottom
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildAnimatedMoreMenuItem(
    BuildContext context, 
    Icon icon, 
    String title, 
    String route, 
    int index, 
    {Color textColor = Colors.white}
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 100 + (index * 100)),
      curve: Curves.easeOutQuad,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: ListTile(
        leading: icon,
        title: Text(
          title,
          style: TextStyle(color: textColor),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        onTap: () async {
          Navigator.pop(context);
          
          // Special handling for logout
          if (route == '/login') {
            try {
              // Close WebSocket connection before logout
              final webSocketProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
              await webSocketProvider.logout();
            } catch (e) {
              print('Error during logout: $e');
            }
          }
          
          widget.onDestinationSelected(route);
        },
      ),
    );
  }
}
