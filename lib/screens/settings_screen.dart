import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/desktop_menu.dart';
import '../widgets/mobile_menu.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  bool _isMenuExpanded = true;
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  void _toggleMenu() {
    setState(() {
      _isMenuExpanded = !_isMenuExpanded;
    });
  }
  
  void _navigate(String route) {
    Navigator.pushReplacementNamed(context, route);
  }
  
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Settings',
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {},
            tooltip: 'Save Settings',
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      drawer: isMobile
          ? MobileDrawer(
              currentRoute: '/settings',
              onNavigate: _navigate,
            )
          : null,
      bottomNavigationBar: isMobile
          ? MobileMenu(
              currentRoute: '/settings',
              onNavigate: _navigate,
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            DesktopMenu(
              currentRoute: '/settings',
              onNavigate: _navigate,
              isExpanded: _isMenuExpanded,
              onToggleExpand: _toggleMenu,
            ),
          Expanded(
            child: Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGeneralSettings(),
                      _buildUserManagement(),
                      _buildCameraGroups(),
                      _buildDeviceGroups(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      color: AppTheme.darkSurface,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.blueAccent,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.blueAccent,
        indicatorWeight: 3.0,
        tabs: const [
          Tab(
            icon: Icon(Icons.settings),
            text: 'General',
          ),
          Tab(
            icon: Icon(Icons.people),
            text: 'Users',
          ),
          Tab(
            icon: Icon(Icons.camera_alt),
            text: 'Camera Groups',
          ),
          Tab(
            icon: Icon(Icons.devices),
            text: 'Device Groups',
          ),
        ],
      ),
    );
  }
  
  Widget _buildGeneralSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('System Settings'),
          _buildSettingsCard([
            _buildSwitchSetting(
              'Dark Theme',
              'Enable dark theme for the application',
              true,
              (value) {},
            ),
            const Divider(),
            _buildSwitchSetting(
              'Auto Refresh',
              'Automatically refresh device status every 60 seconds',
              true,
              (value) {},
            ),
            const Divider(),
            _buildDropdownSetting(
              'Default View',
              'Set the default view for cameras',
              'Grid View',
              ['Grid View', 'List View', 'Tile View'],
              (value) {},
            ),
          ]),
          
          const SizedBox(height: 24.0),
          _buildSectionHeader('Notification Settings'),
          _buildSettingsCard([
            _buildSwitchSetting(
              'Email Notifications',
              'Receive email notifications for alerts',
              true,
              (value) {},
            ),
            const Divider(),
            _buildSwitchSetting(
              'Push Notifications',
              'Receive push notifications on mobile devices',
              false,
              (value) {},
            ),
            const Divider(),
            _buildSwitchSetting(
              'Sound Alerts',
              'Play sound when alerts are triggered',
              true,
              (value) {},
            ),
          ]),
          
          const SizedBox(height: 24.0),
          _buildSectionHeader('Storage Settings'),
          _buildSettingsCard([
            _buildSliderSetting(
              'Retention Period',
              'Number of days to keep recordings',
              30,
              (value) {},
              min: 1,
              max: 90,
              divisions: 89,
              suffix: 'days',
            ),
            const Divider(),
            _buildDropdownSetting(
              'Recording Quality',
              'Default quality for recordings',
              'High (1080p)',
              ['Low (480p)', 'Medium (720p)', 'High (1080p)', 'Ultra (4K)'],
              (value) {},
            ),
            const Divider(),
            _buildSwitchSetting(
              'Auto Delete',
              'Automatically delete oldest recordings when storage is full',
              true,
              (value) {},
            ),
          ]),
          
          const SizedBox(height: 24.0),
          _buildActionButtons(),
        ],
      ),
    );
  }
  
  Widget _buildUserManagement() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('User Accounts'),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          _buildUsersList(),
          
          const SizedBox(height: 24.0),
          _buildSectionHeader('User Roles'),
          _buildRolesCard(),
          
          const SizedBox(height: 24.0),
          _buildSectionHeader('Login Settings'),
          _buildSettingsCard([
            _buildSwitchSetting(
              'Two-Factor Authentication',
              'Require 2FA for all admin accounts',
              true,
              (value) {},
            ),
            const Divider(),
            _buildDropdownSetting(
              'Session Timeout',
              'Automatically log out after inactivity',
              '30 minutes',
              ['15 minutes', '30 minutes', '1 hour', '4 hours', 'Never'],
              (value) {},
            ),
            const Divider(),
            _buildSwitchSetting(
              'Failed Login Lockout',
              'Lock account after 5 failed login attempts',
              true,
              (value) {},
            ),
          ]),
        ],
      ),
    );
  }
  
  Widget _buildCameraGroups() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Camera Groups'),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add Group'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          _buildGroupsList([
            {
              'name': 'Front Entrance',
              'count': 4,
              'status': 'All Online',
              'color': AppTheme.blueAccent,
            },
            {
              'name': 'Parking Lot',
              'count': 6,
              'status': '1 Offline',
              'color': AppTheme.orangeAccent,
            },
            {
              'name': 'Internal Offices',
              'count': 8,
              'status': 'All Online',
              'color': AppTheme.blueAccent,
            },
            {
              'name': 'Warehouse',
              'count': 5,
              'status': '2 Offline',
              'color': AppTheme.orangeAccent,
            },
            {
              'name': 'Back Entrance',
              'count': 3,
              'status': 'All Online',
              'color': AppTheme.blueAccent,
            },
          ]),
          
          const SizedBox(height: 24.0),
          _buildSectionHeader('Default Settings for New Groups'),
          _buildSettingsCard([
            _buildDropdownSetting(
              'Recording Mode',
              'Default recording mode for new camera groups',
              'Motion Detection',
              ['Always', 'Motion Detection', 'Scheduled', 'Manual'],
              (value) {},
            ),
            const Divider(),
            _buildSwitchSetting(
              'Motion Alerts',
              'Enable motion alerts for new camera groups',
              true,
              (value) {},
            ),
            const Divider(),
            _buildSliderSetting(
              'Motion Sensitivity',
              'Default motion detection sensitivity',
              70,
              (value) {},
              min: 0,
              max: 100,
              divisions: 100,
              suffix: '%',
            ),
          ]),
        ],
      ),
    );
  }
  
  Widget _buildDeviceGroups() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Device Groups'),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add Group'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          _buildGroupsList([
            {
              'name': 'Network Infrastructure',
              'count': 5,
              'status': 'All Online',
              'color': AppTheme.blueAccent,
            },
            {
              'name': 'Storage Servers',
              'count': 3,
              'status': 'All Online',
              'color': AppTheme.blueAccent,
            },
            {
              'name': 'NVR Systems',
              'count': 2,
              'status': '1 Warning',
              'color': AppTheme.orangeAccent,
            },
            {
              'name': 'Remote Access',
              'count': 4,
              'status': '1 Offline',
              'color': AppTheme.errorColor,
            },
          ]),
          
          const SizedBox(height: 24.0),
          _buildSectionHeader('Maintenance Settings'),
          _buildSettingsCard([
            _buildSwitchSetting(
              'Auto Updates',
              'Automatically install firmware updates',
              false,
              (value) {},
            ),
            const Divider(),
            _buildDropdownSetting(
              'Maintenance Window',
              'Schedule maintenance during low-usage hours',
              '2:00 AM - 4:00 AM',
              ['12:00 AM - 2:00 AM', '2:00 AM - 4:00 AM', '4:00 AM - 6:00 AM', 'Manually Schedule'],
              (value) {},
            ),
            const Divider(),
            _buildDropdownSetting(
              'Backup Frequency',
              'How often to back up device configurations',
              'Weekly',
              ['Daily', 'Weekly', 'Monthly', 'Never'],
              (value) {},
            ),
          ]),
          
          const SizedBox(height: 24.0),
          _buildSectionHeader('Network Settings'),
          _buildSettingsCard([
            _buildDropdownSetting(
              'IP Assignment',
              'How IP addresses are assigned to new devices',
              'DHCP with Reservation',
              ['DHCP', 'DHCP with Reservation', 'Static IP'],
              (value) {},
            ),
            const Divider(),
            _buildDropdownSetting(
              'Default Subnet',
              'Subnet for new devices',
              '192.168.1.0/24',
              ['192.168.1.0/24', '10.0.0.0/24', '172.16.0.0/24'],
              (value) {},
            ),
            const Divider(),
            _buildSwitchSetting(
              'Remote Access',
              'Allow devices to be accessed remotely',
              true,
              (value) {},
            ),
          ]),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
  
  Widget _buildSwitchSetting(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.blueAccent,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDropdownSetting(
    String title,
    String subtitle,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                dropdownColor: AppTheme.darkSurface,
                icon: const Icon(Icons.arrow_drop_down),
                items: options.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSliderSetting(
    String title,
    String subtitle,
    double value,
    Function(double) onChanged, {
    double min = 0.0,
    double max = 100.0,
    int divisions = 100,
    String suffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16.0,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14.0,
            ),
          ),
          const SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
                    activeTrackColor: AppTheme.blueAccent,
                    inactiveTrackColor: AppTheme.textSecondary.withOpacity(0.3),
                    thumbColor: AppTheme.blueAccent,
                    overlayColor: AppTheme.blueAccent.withOpacity(0.3),
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                  ),
                ),
              ),
              const SizedBox(width: 16.0),
              Container(
                width: 60.0,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  '${value.toInt()}$suffix',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: const BorderSide(color: AppTheme.textSecondary),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          ),
          child: const Text('Reset to Defaults'),
        ),
        const SizedBox(width: 16.0),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          ),
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
  
  Widget _buildUsersList() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildUserListItem(
              'John Smith',
              'Administrator',
              'Last login: Today, 10:45 AM',
              Icons.admin_panel_settings,
              AppTheme.blueAccent,
            ),
            const Divider(),
            _buildUserListItem(
              'Sarah Johnson',
              'Manager',
              'Last login: Yesterday, 3:22 PM',
              Icons.manage_accounts,
              AppTheme.blueAccent,
            ),
            const Divider(),
            _buildUserListItem(
              'Michael Brown',
              'Operator',
              'Last login: 3 days ago',
              Icons.person,
              AppTheme.textSecondary,
            ),
            const Divider(),
            _buildUserListItem(
              'Jessica Williams',
              'Viewer',
              'Last login: 1 week ago',
              Icons.remove_red_eye,
              AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUserListItem(
    String name,
    String role,
    String lastLogin,
    IconData icon,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40.0,
            height: 40.0,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  '$role • $lastLogin',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20.0),
            onPressed: () {},
            splashRadius: 24.0,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20.0),
            onPressed: () {},
            splashRadius: 24.0,
            tooltip: 'Delete',
            color: Colors.red.shade300,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRolesCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildRoleItem(
              'Administrator',
              'Full system access and configuration rights',
              AppTheme.blueAccent,
            ),
            const Divider(),
            _buildRoleItem(
              'Manager',
              'Can manage cameras, devices, and view all content',
              AppTheme.blueAccent,
            ),
            const Divider(),
            _buildRoleItem(
              'Operator',
              'Can view live feeds and recordings, limited configuration',
              AppTheme.orangeAccent,
            ),
            const Divider(),
            _buildRoleItem(
              'Viewer',
              'Can only view live feeds, no configuration access',
              AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRoleItem(
    String role,
    String description,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 12.0,
            height: 12.0,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16.0,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20.0),
            onPressed: () {},
            splashRadius: 24.0,
            tooltip: 'Edit Permissions',
          ),
        ],
      ),
    );
  }
  
  Widget _buildGroupsList(List<Map<String, dynamic>> groups) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: BoxDecoration(
                    color: (group['color'] as Color).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Icon(
                    index % 2 == 0 ? Icons.camera_alt : Icons.devices,
                    color: group['color'] as Color,
                    size: 24.0,
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16.0,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Row(
                        children: [
                          Text(
                            '${group['count']} devices',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14.0,
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: (group['color'] as Color).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text(
                              group['status'] as String,
                              style: TextStyle(
                                color: group['color'] as Color,
                                fontSize: 12.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20.0),
                      onPressed: () {},
                      splashRadius: 24.0,
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20.0),
                      onPressed: () {},
                      splashRadius: 24.0,
                      tooltip: 'Delete',
                      color: Colors.red.shade300,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
