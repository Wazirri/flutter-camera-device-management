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
    final menuItems = MenuItems.getMenuItems(currentRoute: currentRoute);
    
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppTheme.darkSurface,
      selectedItemColor: AppTheme.primaryBlue,
      unselectedItemColor: AppTheme.darkTextSecondary,
      currentIndex: _getCurrentIndex(menuItems),
      onTap: (index) => onDestinationSelected(menuItems[index].route),
      items: menuItems.map((item) => BottomNavigationBarItem(
        icon: Icon(item.icon),
        label: item.title,
      )).toList(),
    );
  }
  
  int _getCurrentIndex(List<CustomMenuItem> items) {
    final index = items.indexWhere((item) => item.isSelected);
    return index >= 0 ? index : 0;
  }
}