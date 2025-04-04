import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';

class DesktopSideMenu extends StatefulWidget {
  final String currentRoute;
  final Function(String) onDestinationSelected;

  const DesktopSideMenu({
    super.key,
    required this.currentRoute,
    required this.onDestinationSelected,
  });

  @override
  State<DesktopSideMenu> createState() => _DesktopSideMenuState();
}

class _DesktopSideMenuState extends State<DesktopSideMenu> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
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
    return Container(
      width: 240,
      color: AppTheme.darkSurface,
      child: Column(
        children: [
          // App logo and title with fade-in animation
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/app_logo.png',
                    width: 60,
                    height: 60,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.video_camera_back,
                        size: 60,
                        color: AppTheme.primaryColor,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
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
          
          // Menu items with staggered animations
          Expanded(
            child: AnimatedList(
              initialItemCount: 9, // Total number of menu items
              itemBuilder: (context, index, animation) {
                // Calculate a staggered delay based on the index
                final delayedAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Interval(0.1 * index, 0.1 * index + 0.9, curve: Curves.easeOutQuad),
                  ),
                );
                
                // Return different widgets based on the index
                if (index == 0) {
                  return _buildAnimatedMenuItem(
                    context,
                    'Dashboard',
                    Icons.dashboard,
                    '/dashboard',
                    delayedAnimation,
                  );
                } else if (index == 1) {
                  return _buildAnimatedMenuItem(
                    context,
                    'Live View',
                    Icons.videocam,
                    '/live-view',
                    delayedAnimation,
                  );
                } else if (index == 2) {
                  return _buildAnimatedMenuItem(
                    context,
                    'Recordings',
                    Icons.video_library,
                    '/recordings',
                    delayedAnimation,
                  );
                } else if (index == 3) {
                  // Section divider
                  return FadeTransition(
                    opacity: delayedAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                          child: Text(
                            'DEVICES',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.darkTextSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (index == 4) {
                  return _buildAnimatedMenuItem(
                    context,
                    'Camera Devices',
                    Icons.devices,
                    '/camera-devices',
                    delayedAnimation,
                  );
                } else if (index == 5) {
                  return _buildAnimatedMenuItem(
                    context,
                    'Cameras',
                    Icons.camera,
                    '/cameras',
                    delayedAnimation,
                  );
                } else if (index == 6) {
                  return _buildAnimatedMenuItem(
                    context,
                    'Devices',
                    Icons.device_hub,
                    '/devices',
                    delayedAnimation,
                  );
                } else if (index == 7) {
                  return FadeTransition(
                    opacity: delayedAnimation,
                    child: const Divider(height: 1),
                  );
                } else {
                  // Settings and logs
                  return Column(
                    children: [
                      _buildAnimatedMenuItem(
                        context,
                        'Settings',
                        Icons.settings,
                        '/settings',
                        delayedAnimation,
                      ),
                      _buildAnimatedMenuItem(
                        context,
                        'WebSocket Logs',
                        Icons.feed,
                        '/websocket-logs',
                        delayedAnimation,
                      ),
                    ],
                  );
                }
              },
            ),
          ),
          
          // Footer
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    String route,
    Animation<double> animation,
  ) {
    final isSelected = widget.currentRoute == route;
    
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.5, 0.0),
          end: Offset.zero,
        ).animate(animation),
        child: _buildMenuItem(context, title, icon, route, isSelected),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    IconData icon,
    String route,
    bool isSelected,
  ) {
    // Add an animation on tap
    return InkWell(
      onTap: () {
        // Add a subtle animation when tapped
        _animationController.reverse().then((_) {
          widget.onDestinationSelected(route);
          _animationController.forward();
        });
      },
      onHover: (hovering) {
        // Optional: add hover animation if desired
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? AppTheme.accentColor.withOpacity(0.15) : Colors.transparent,
        ),
        child: ListTile(
          selected: isSelected,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          leading: Icon(
            icon,
            color: isSelected ? AppTheme.accentColor : AppTheme.darkTextSecondary,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? AppTheme.accentColor : AppTheme.darkTextPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
