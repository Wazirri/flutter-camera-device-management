import '../providers/websocket_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
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

class _DesktopSideMenuState extends State<DesktopSideMenu> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final menuItems = MenuItems.getMenuItems(currentRoute: widget.currentRoute);
    final double menuWidth = _isCollapsed ? 70 : 250;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: menuWidth,
      child: Drawer(
        backgroundColor: AppTheme.darkSurface,
        elevation: 0,
        child: Column(
          children: [
            // Header with collapse button
            Container(
              height: _isCollapsed ? 80 : 150,
              decoration: const BoxDecoration(
                color: AppTheme.darkBackground,
              ),
              child: _isCollapsed
                  ? Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.video_camera_back_rounded,
                          size: 32,
                          color: AppTheme.primaryOrange,
                        ),
                        onPressed: () => setState(() => _isCollapsed = false),
                        tooltip: 'Expand Menu',
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.video_camera_back_rounded,
                          size: 48,
                          color: AppTheme.primaryOrange,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Camera Device Manager',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // Collapse button
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white54, size: 20),
                          onPressed: () => setState(() => _isCollapsed = true),
                          tooltip: 'Collapse Menu',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: menuItems.length,
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  if (_isCollapsed) {
                    // Collapsed: show only icons with tooltip
                    return Tooltip(
                      message: item.title,
                      preferBelow: false,
                      waitDuration: const Duration(milliseconds: 300),
                      child: InkWell(
                        onTap: () => widget.onDestinationSelected(item.route),
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: item.isSelected 
                                ? AppTheme.primaryBlue.withOpacity(0.2)
                                : Colors.transparent,
                            border: item.isSelected
                                ? const Border(
                                    left: BorderSide(color: AppTheme.primaryBlue, width: 3),
                                  )
                                : null,
                          ),
                          child: Icon(
                            item.icon,
                            color: item.isSelected
                                ? AppTheme.primaryBlue
                                : AppTheme.darkTextSecondary,
                          ),
                        ),
                      ),
                    );
                  }
                  // Expanded: show full list tile
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
                    onTap: () => widget.onDestinationSelected(item.route),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Logout button
            if (_isCollapsed)
              Tooltip(
                message: 'Logout',
                child: InkWell(
                  onTap: () => _handleLogout(context),
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    child: const Icon(Icons.logout, color: AppTheme.darkTextSecondary),
                  ),
                ),
              )
            else
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.darkTextSecondary),
                title: const Text('Logout', style: TextStyle(color: AppTheme.darkTextPrimary)),
                onTap: () => _handleLogout(context),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    try {
      Future.delayed(Duration.zero, () {
        Provider.of<WebSocketProviderOptimized>(context, listen: false).logout();
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      });
    } catch (e) {
      print('Error during logout: $e');
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
}