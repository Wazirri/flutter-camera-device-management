import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/desktop_menu.dart';
import '../widgets/mobile_menu.dart';
import '../widgets/status_indicator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isMenuExpanded = true;
  
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
        title: 'Dashboard',
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {},
            tooltip: 'Profile',
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      drawer: isMobile
          ? MobileDrawer(
              currentRoute: '/dashboard',
              onNavigate: _navigate,
            )
          : null,
      bottomNavigationBar: isMobile
          ? MobileMenu(
              currentRoute: '/dashboard',
              onNavigate: _navigate,
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            DesktopMenu(
              currentRoute: '/dashboard',
              onNavigate: _navigate,
              isExpanded: _isMenuExpanded,
              onToggleExpand: _toggleMenu,
            ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: _buildDashboardContent(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCards(),
          const SizedBox(height: 24.0),
          _buildDeviceOverview(),
          const SizedBox(height: 24.0),
          _buildRecentActivity(),
        ],
      ),
    );
  }
  
  Widget _buildStatusCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: ResponsiveHelper.getCrossAxisCount(context),
      crossAxisSpacing: 16.0,
      mainAxisSpacing: 16.0,
      children: [
        _buildStatusCard(
          icon: Icons.videocam,
          title: 'Cameras',
          count: '24',
          status: 'Active: 18',
          color: AppTheme.blueAccent,
        ),
        _buildStatusCard(
          icon: Icons.devices,
          title: 'Devices',
          count: '32',
          status: 'Active: 28',
          color: AppTheme.orangeAccent,
        ),
        _buildStatusCard(
          icon: Icons.error_outline,
          title: 'Alerts',
          count: '5',
          status: 'Critical: 2',
          color: Colors.red,
        ),
        _buildStatusCard(
          icon: Icons.storage,
          title: 'Storage',
          count: '2.4TB',
          status: '68% Used',
          color: Colors.green,
        ),
      ],
    );
  }
  
  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String count,
    required String status,
    required Color color,
  }) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28.0,
              ),
            ),
            const Spacer(),
            Text(
              count,
              style: const TextStyle(
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16.0,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              status,
              style: TextStyle(
                fontSize: 14.0,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDeviceOverview() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'System Overview',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.more_vert,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            const Divider(),
            const SizedBox(height: 16.0),
            _buildSystemStatusItem(
              'Network Status',
              DeviceStatus.online,
              'Connected - 1Gbps',
            ),
            const SizedBox(height: 12.0),
            _buildSystemStatusItem(
              'Storage Health',
              DeviceStatus.warning,
              '68% Used - 2.4TB of 4TB',
            ),
            const SizedBox(height: 12.0),
            _buildSystemStatusItem(
              'Server Status',
              DeviceStatus.online,
              'Running - Load: 35%',
            ),
            const SizedBox(height: 12.0),
            _buildSystemStatusItem(
              'Last Backup',
              DeviceStatus.online,
              'Today, 03:15 AM',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSystemStatusItem(
    String title,
    DeviceStatus status,
    String details,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        StatusIndicator(
          status: status,
          showLabel: true,
        ),
        const SizedBox(width: 16.0),
        Expanded(
          flex: 3,
          child: Text(
            details,
            style: const TextStyle(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecentActivity() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'View All',
                  style: TextStyle(
                    color: AppTheme.blueAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            const Divider(),
            _buildActivityItem(
              icon: Icons.videocam,
              title: 'Camera 3 went offline',
              time: '10 minutes ago',
              color: Colors.red,
            ),
            const Divider(),
            _buildActivityItem(
              icon: Icons.warning_amber,
              title: 'Motion detected on Camera 5',
              time: '35 minutes ago',
              color: AppTheme.orangeAccent,
            ),
            const Divider(),
            _buildActivityItem(
              icon: Icons.login,
              title: 'Admin user logged in',
              time: '1 hour ago',
              color: AppTheme.blueAccent,
            ),
            const Divider(),
            _buildActivityItem(
              icon: Icons.backup,
              title: 'System backup completed',
              time: '3 hours ago',
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String time,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20.0,
            ),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  time,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}
