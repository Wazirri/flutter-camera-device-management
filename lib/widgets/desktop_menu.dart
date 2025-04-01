import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../theme/app_theme.dart';

class DesktopSideMenu extends StatelessWidget {
  final String currentRoute;
  final Function(String) onDestinationSelected;

  const DesktopSideMenu({
    Key? key,
    required this.currentRoute,
    required this.onDestinationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final menuItems = MenuItems.getMenuItems(currentRoute: currentRoute);
    
    return SizedBox(
      width: 250,
      child: Drawer(
        backgroundColor: AppTheme.darkSurface,
        elevation: 0,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: AppTheme.darkBackground,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_camera_back_rounded,
                      size: 48,
                      color: AppTheme.primaryOrange,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera Device Manager',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: menuItems.length,
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  return ListTile(
                    leading: Icon(
                      item.icon,
                      color: item.isSelected
                          ? AppTheme.primaryBlue
                          : AppTheme.darkTextSecondary,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        color: item.isSelected
                            ? AppTheme.primaryBlue
                            : AppTheme.darkTextPrimary,
                        fontWeight: item.isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    selected: item.isSelected,
                    selectedColor: AppTheme.primaryBlue,
                    hoverColor: Colors.white.withOpacity(0.05),
                    onTap: () => onDestinationSelected(item.route),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.darkTextSecondary),
              title: const Text('Logout', style: TextStyle(color: AppTheme.darkTextPrimary)),
              onTap: () {
                // Navigate to login screen
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}