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
      final menuItems = MenuItems.getMenuItems(currentRoute: currentRoute);
      
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.darkSurface,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: AppTheme.darkTextSecondary,
        currentIndex: _getCurrentIndex(menuItems),
        onTap: (index) {
          try {
            // Handle onTap with error catching
            if (index >= 0 && index < menuItems.length) {
              onDestinationSelected(menuItems[index].route);
            }
          } catch (e) {
            debugPrint('Error in bottom navigation tap: $e');
          }
        },
        items: menuItems.map((item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: item.title,
        )).toList(),
      );
    } catch (e) {
      // Fallback in case of error
      debugPrint('Error building mobile menu: $e');
      return const SizedBox.shrink(); // Return empty widget instead of crashing
    }
  }
  
  int _getCurrentIndex(List<CustomMenuItem> items) {
    final index = items.indexWhere((item) => item.isSelected);
    return index >= 0 ? index : 0;
  }
}