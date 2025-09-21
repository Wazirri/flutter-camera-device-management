import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../theme/app_theme.dart';

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
    try {
      // Create a subset of menu items for mobile navigation
      // We need to limit items because BottomNavigationBar has limited space
      final allMenuItems = MenuItems.getMenuItems(currentRoute: currentRoute);
      final mobileMenuItems = [
        // Dashboard
        allMenuItems.firstWhere((item) => item.route == '/dashboard'),
        // Live View
        allMenuItems.firstWhere((item) => item.route == '/live-view'),
        // Recording Download
        allMenuItems.firstWhere((item) => item.route == '/recording-download'),
        // Camera Devices (our new feature)
        allMenuItems.firstWhere((item) => item.route == '/camera-devices'),
        // Settings
        allMenuItems.firstWhere((item) => item.route == '/settings'),
      ];
      
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.darkSurface,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: AppTheme.darkTextSecondary,
        currentIndex: _getCurrentIndex(mobileMenuItems),
        onTap: (index) {
          try {
            // Handle onTap with error catching
            if (index >= 0 && index < mobileMenuItems.length) {
              onDestinationSelected(mobileMenuItems[index].route);
            }
          } catch (e) {
            print('Error in bottom navigation tap: $e');
          }
        },
        items: mobileMenuItems.map((item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: item.title,
        )).toList(),
      );
    } catch (e) {
      // Fallback in case of error
      print('Error building mobile menu: $e');
      return const SizedBox.shrink(); // Return empty widget instead of crashing
    }
  }
  
  int _getCurrentIndex(List<CustomMenuItem> items) {
    final index = items.indexWhere((item) => item.isSelected);
    return index >= 0 ? index : 0;
  }
}