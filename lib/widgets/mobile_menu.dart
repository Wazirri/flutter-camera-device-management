import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/menu_item.dart';

class MobileMenu extends StatelessWidget {
  final String currentRoute;
  final Function(String) onNavigate;
  
  const MobileMenu({
    Key? key,
    required this.currentRoute,
    required this.onNavigate,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _getCurrentIndex(),
      onTap: (index) {
        if (index < AppMenuItems.items.length) {
          onNavigate(AppMenuItems.items[index].route);
        }
      },
      items: AppMenuItems.items.take(5).map((item) {
        return BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: item.title,
        );
      }).toList(),
      selectedItemColor: AppTheme.blueAccent,
      unselectedItemColor: AppTheme.textSecondary,
      showUnselectedLabels: true,
      backgroundColor: AppTheme.darkSurface,
      type: BottomNavigationBarType.fixed,
    );
  }
  
  int _getCurrentIndex() {
    final index = AppMenuItems.items.indexWhere((item) => item.route == currentRoute);
    return index >= 0 && index < 5 ? index : 0;
  }
}

class MobileDrawer extends StatelessWidget {
  final String currentRoute;
  final Function(String) onNavigate;
  
  const MobileDrawer({
    Key? key,
    required this.currentRoute,
    required this.onNavigate,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: AppTheme.darkBackground,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ...AppMenuItems.items.map((item) {
                    return _buildMenuItem(context, item);
                  }).toList(),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help & Support'),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout'),
                    onTap: () {
                      Navigator.pop(context);
                      onNavigate('/login');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return DrawerHeader(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkBackground, AppTheme.darkSurface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60.0,
            height: 60.0,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.blueAccent, AppTheme.orangeAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: const Center(
              child: Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 32.0,
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          const Text(
            'Camera & Device Manager',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.0,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuItem(BuildContext context, AppMenuItem item) {
    final isSelected = currentRoute == item.route;
    
    return ListTile(
      selected: isSelected,
      leading: Icon(
        item.icon,
        color: isSelected ? AppTheme.blueAccent : null,
      ),
      title: Text(
        item.title,
        style: TextStyle(
          color: isSelected ? AppTheme.blueAccent : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onNavigate(item.route);
      },
    );
  }
}
