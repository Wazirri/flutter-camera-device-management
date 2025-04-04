import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/websocket_provider.dart';
import '../models/system_info.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/status_indicator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _refreshTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Schedule first refresh for when the screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSystemInfo();
    });
    
    // Set up a timer to periodically refresh system information
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshSystemInfo();
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  void _refreshSystemInfo() {
    final provider = Provider.of<WebSocketProvider>(context, listen: false);
    provider.sendSystemMonitorRequest();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: CustomAppBar(
        title: 'Dashboard',
        isDesktop: isDesktop,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(context),
              const SizedBox(height: 24),
              _buildSystemInfoSection(context),
              const SizedBox(height: 24),
              _buildOverviewCards(context),
              const SizedBox(height: 24),
              _buildCameraSection(context),
              const SizedBox(height: 24),
              _buildDeviceSection(context),
              // Add extra space at the bottom to avoid overflow
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Card(
      color: AppTheme.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back, Admin',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Here\'s what\'s happening with your cameras and devices',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // No implementation, UI only
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.add),
                            SizedBox(width: 8),
                            Text('Add New Device'),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/camera-devices');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryBlue,
                          side: BorderSide(color: AppTheme.primaryBlue),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.camera_enhance_rounded),
                            SizedBox(width: 8),
                            Text('Camera Devices'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (ResponsiveHelper.isDesktop(context) || ResponsiveHelper.isTablet(context))
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.video_camera_back_rounded,
                  size: 80,
                  color: AppTheme.primaryBlue,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfoSection(BuildContext context) {
    final webSocketProvider = Provider.of<WebSocketProvider>(context);
    final systemInfo = webSocketProvider.systemInfo;
    
    return Card(
      color: AppTheme.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _buildSystemInfoItem(
                  title: 'Uptime',
                  value: _formatUptime(systemInfo?.upTime ?? '0'),
                  icon: Icons.timelapse,
                ),
                _buildSystemInfoItem(
                  title: 'CPU Usage',
                  value: '${systemInfo?.cpuUsage ?? "0"}%',
                  icon: Icons.memory,
                ),
                _buildSystemInfoItem(
                  title: 'CPU Temp',
                  value: '${systemInfo?.cpuTemp ?? "0"}°C',
                  icon: Icons.thermostat,
                ),
                _buildSystemInfoItem(
                  title: 'RAM Usage',
                  value: '${systemInfo?.ramUsage ?? "0"}%',
                  icon: Icons.storage,
                ),
                _buildSystemInfoItem(
                  title: 'Disk Space',
                  value: '${systemInfo?.diskUsage ?? "0"}%',
                  icon: Icons.sd_storage,
                ),
                _buildSystemInfoItem(
                  title: 'Network',
                  value: systemInfo?.connectionStatus ?? 'Unknown',
                  icon: Icons.wifi,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfoItem({
    required String title,
    required String value,
    required IconData icon,
  }) {
    // Fix overflow by giving it fixed width and using Expanded
    return SizedBox(
      width: 160, // Fixed width to prevent overflow
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Use Expanded for text to handle long values
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.darkTextPrimary,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkTextSecondary,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatUptime(String uptimeSeconds) {
    try {
      final seconds = int.parse(uptimeSeconds);
      final hours = (seconds / 3600).floor();
      final minutes = ((seconds % 3600) / 60).floor();
      
      if (hours > 0) {
        return '$hours h ${minutes} m';
      } else {
        return '$minutes min';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildOverviewCards(BuildContext context) {
    final isSmallScreen = ResponsiveHelper.isMobile(context);
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isSmallScreen ? 2 : 4,
      childAspectRatio: isSmallScreen ? 1.2 : 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          context,
          title: 'Total Cameras',
          value: '12',
          icon: Icons.camera_alt_rounded,
          color: AppTheme.primaryBlue,
        ),
        _buildStatCard(
          context,
          title: 'Active Devices',
          value: '8',
          icon: Icons.devices_rounded,
          color: AppTheme.online,
        ),
        _buildStatCard(
          context,
          title: 'Alerts',
          value: '3',
          icon: Icons.warning_amber_rounded,
          color: AppTheme.warning,
        ),
        _buildStatCard(
          context,
          title: 'Recordings',
          value: '46',
          icon: Icons.video_library_rounded,
          color: AppTheme.primaryOrange,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: AppTheme.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Camera Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/camera-devices');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min, // Make sure row only takes needed space
                children: const [
                  Text('View All'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) {
              return _buildCameraActivityCard(
                context,
                name: 'Camera ${index + 1}',
                location: 'Location ${index + 1}',
                timestamp: '${index + 1}h ago',
                status: index % 3 == 0 ? DeviceStatus.warning : DeviceStatus.online,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCameraActivityCard(
    BuildContext context, {
    required String name,
    required String location,
    required String timestamp,
    required DeviceStatus status,
  }) {
    return Card(
      color: AppTheme.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(right: 16),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded( // Added Expanded
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.videocam_rounded,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded( // Added Expanded
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.darkTextPrimary,
                                overflow: TextOverflow.ellipsis, // Add ellipsis
                              ),
                              maxLines: 1, // Limit to one line
                            ),
                            Text(
                              location,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.darkTextSecondary,
                                overflow: TextOverflow.ellipsis, // Add ellipsis
                              ),
                              maxLines: 1, // Limit to one line
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                StatusIndicator(status: status),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Motion detected',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.darkTextPrimary,
                overflow: TextOverflow.ellipsis, // Add ellipsis
              ),
              maxLines: 1, // Limit to one line
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppTheme.darkTextSecondary,
                ),
                const SizedBox(width: 4),
                Expanded( // Added Expanded
                  child: Text(
                    timestamp,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.darkTextSecondary,
                      overflow: TextOverflow.ellipsis, // Add ellipsis
                    ),
                    maxLines: 1, // Limit to one line
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // No implementation, UI only
                  },
                  child: const Text('View Recording'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Device Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/camera-devices');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min, // Make sure row only takes needed space
                children: const [
                  Text('View All'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: AppTheme.darkSurface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildDeviceStatusTable(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceStatusTable(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 150,
              child: Text(
                'Device Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                'Type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                'Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ),
            if (!ResponsiveHelper.isMobile(context))
              SizedBox(
                width: 120,
                child: Text(
                  'Last Seen',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkTextSecondary,
                  ),
                ),
              ),
            SizedBox(
              width: 120,
              child: Text(
                'Actions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          children: List.generate(
            5,
            (index) => _buildDeviceStatusRow(
              context,
              name: 'Device ${index + 1}',
              type: index % 2 == 0 ? 'NVR' : 'DVR',
              status: index % 3 == 0 ? DeviceStatus.warning : DeviceStatus.online,
              lastSeen: '${index + 1} min ago',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceStatusRow(
    BuildContext context, {
    required String name,
    required String type,
    required DeviceStatus status,
    required String lastSeen,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.devices,
                    color: AppTheme.primaryBlue,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.darkTextPrimary,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              type,
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Row(
              children: [
                StatusIndicator(status: status),
                const SizedBox(width: 8),
                Text(
                  status == DeviceStatus.online
                      ? 'Online'
                      : status == DeviceStatus.warning
                          ? 'Warning'
                          : 'Offline',
                  style: TextStyle(
                    color: status == DeviceStatus.online
                        ? AppTheme.online
                        : status == DeviceStatus.warning
                            ? AppTheme.warning
                            : AppTheme.error,
                  ),
                ),
              ],
            ),
          ),
          if (!ResponsiveHelper.isMobile(context))
            SizedBox(
              width: 120,
              child: Text(
                lastSeen,
                style: const TextStyle(
                  color: AppTheme.darkTextPrimary,
                ),
              ),
            ),
          SizedBox(
            width: 120,
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    // No implementation, UI only
                  },
                  icon: const Icon(
                    Icons.settings,
                    size: 18,
                    color: AppTheme.darkTextSecondary,
                  ),
                  tooltip: 'Settings',
                ),
                IconButton(
                  onPressed: () {
                    // No implementation, UI only
                  },
                  icon: const Icon(
                    Icons.refresh,
                    size: 18,
                    color: AppTheme.darkTextSecondary,
                  ),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
