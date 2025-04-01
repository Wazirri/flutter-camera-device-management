import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/menu_item.dart';

class DesktopMenu extends StatelessWidget {
  final String currentRoute;
  final Function(String) onNavigate;
  final bool isExpanded;
  final Function() onToggleExpand;
  
  const DesktopMenu({
    Key? key,
    required this.currentRoute,
    required this.onNavigate,
    this.isExpanded = true,
    required this.onToggleExpand,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isExpanded ? 240.0 : 80.0,
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16.0),
          bottomRight: Radius.circular(16.0),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1.0),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              children: AppMenuItems.items.map((item) {
                return _buildMenuItem(item);
              }).toList(),
            ),
          ),
          const Divider(height: 1.0),
          _buildFooter(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            width: 40.0,
            height: 40.0,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.blueAccent, AppTheme.orangeAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Center(
              child: Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 24.0,
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 16.0),
            const Expanded(
              child: Text(
                'Camera Manager',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
            ),
          ],
          IconButton(
            icon: Icon(
              isExpanded ? Icons.chevron_left : Icons.chevron_right,
              size: 20.0,
            ),
            onPressed: onToggleExpand,
            splashRadius: 24.0,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuItem(AppMenuItem item) {
    final isSelected = currentRoute == item.route;
    
    return ListTile(
      selected: isSelected,
      leading: Icon(
        item.icon,
        color: isSelected ? AppTheme.blueAccent : null,
        size: 24.0,
      ),
      title: isExpanded
          ? Text(
              item.title,
              style: TextStyle(
                color: isSelected ? AppTheme.blueAccent : null,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            )
          : null,
      minLeadingWidth: 0,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isExpanded ? 16.0 : 8.0,
        vertical: 4.0,
      ),
      dense: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      onTap: () => onNavigate(item.route),
      selectedTileColor: AppTheme.blueAccent.withOpacity(0.15),
    );
  }
  
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: isExpanded
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.center,
        children: [
          Tooltip(
            message: 'Settings',
            child: IconButton(
              icon: const Icon(Icons.settings, size: 20.0),
              onPressed: () => onNavigate('/settings'),
              splashRadius: 24.0,
            ),
          ),
          if (isExpanded) ...[
            Tooltip(
              message: 'Help',
              child: IconButton(
                icon: const Icon(Icons.help_outline, size: 20.0),
                onPressed: () {},
                splashRadius: 24.0,
              ),
            ),
            Tooltip(
              message: 'Logout',
              child: IconButton(
                icon: const Icon(Icons.logout, size: 20.0),
                onPressed: () => onNavigate('/login'),
                splashRadius: 24.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
