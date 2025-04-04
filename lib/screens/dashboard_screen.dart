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
                Row(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.darkTextPrimary,
                          ),
                        ),
                        Text(
                          location,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
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
              ),
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
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkTextSecondary,
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
            Container(
              width: 150,
              child: Text(
                'Device Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ),
            Container(
              width: 100,
              child: Text(
                'Type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ),
            Container(
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
              Container(
                width: 120,
                child: Text(
                  'Last Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkTextSecondary,
                  ),
                ),
              ),
            Container(
              width: 50,
              alignment: Alignment.center,
              child: Text(
                '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        ...List.generate(
          4,
          (index) => _buildDeviceStatusRow(
            context,
            name: 'Device ${index + 1}',
            type: index % 2 == 0 ? 'Camera' : 'NVR',
            status: index == 1 ? DeviceStatus.offline : DeviceStatus.online,
            lastActive: '${index * 2}h ago',
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
    required String lastActive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 150,
            child: Text(
              name,
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
              ),
            ),
          ),
          Container(
            width: 100,
            child: Text(
              type,
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
              ),
            ),
          ),
          Container(
            width: 120,
            child: Row(
              children: [
                StatusIndicator(status: status),
                const SizedBox(width: 8),
                Text(
                  status.name,
                  style: const TextStyle(
                    color: AppTheme.darkTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (!ResponsiveHelper.isMobile(context))
            Container(
              width: 120,
              child: Text(
                lastActive,
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ),
          Container(
            width: 50,
            alignment: Alignment.center,
            child: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // No implementation, UI only
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoSection(BuildContext context) {
    // Use Consumer to listen for changes in the WebSocketProvider
    return Consumer<WebSocketProvider>(
      builder: (context, provider, _) {
        final sysInfo = provider.systemInfo;
        final isSmallScreen = ResponsiveHelper.isMobile(context);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'System Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkTextPrimary,
                  ),
                ),
                // Add refresh button to manually refresh
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryBlue),
                  tooltip: 'Refresh System Info',
                  onPressed: _refreshSystemInfo,
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: sysInfo == null
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  'Waiting for system information...',
                                  style: TextStyle(color: AppTheme.darkTextPrimary),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          key: ValueKey<String>('sysInfo-${sysInfo.upTime}'), // Trigger rebuild when uptime changes
                          children: [
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: isSmallScreen ? 2 : 4,
                              childAspectRatio: isSmallScreen ? 1.5 : 2.0,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              children: [
                                _buildSystemInfoCard(
                                  title: 'CPU Temperature',
                                  value: sysInfo.formattedCpuTemp,
                                  icon: Icons.thermostat_outlined,
                                  color: _getTemperatureColor(double.tryParse(sysInfo.cpuTemp) ?? 0),
                                ),
                                _buildSystemInfoCard(
                                  title: 'Uptime',
                                  value: sysInfo.formattedUpTime,
                                  icon: Icons.timer_outlined,
                                  color: AppTheme.primaryBlue,
                                ),
                                _buildSystemInfoCard(
                                  title: 'Server Time',
                                  value: sysInfo.formattedSrvTime,
                                  icon: Icons.access_time,
                                  color: AppTheme.online,
                                ),
                                _buildSystemInfoCard(
                                  title: 'Network Connections',
                                  value: sysInfo.connections,
                                  icon: Icons.wifi,
                                  color: AppTheme.primaryOrange,
                                  subtitle: sysInfo.connections == '0' ? 'No active connections' : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Card(
                              color: AppTheme.darkBackground,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'System Resource Usage',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.darkTextPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (!isSmallScreen)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildLinearProgressBar(
                                              label: 'CPU',
                                              value: double.parse(sysInfo.cpuUsage) / 100,
                                              color: _getUsageColor(double.parse(sysInfo.cpuUsage)),
                                              showPercentage: true,
                                              percentage: '${sysInfo.cpuUsage}%',
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildLinearProgressBar(
                                              label: 'RAM',
                                              value: double.parse(sysInfo.ramUsage) / 100,
                                              color: _getUsageColor(double.parse(sysInfo.ramUsage)),
                                              showPercentage: true,
                                              percentage: '${sysInfo.ramUsage}%',
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildLinearProgressBar(
                                              label: 'Disk',
                                              value: double.parse(sysInfo.diskUsage) / 100,
                                              color: _getUsageColor(double.parse(sysInfo.diskUsage)),
                                              showPercentage: true,
                                              percentage: '${sysInfo.diskUsage}%',
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Column(
                                        children: [
                                          _buildLinearProgressBar(
                                            label: 'CPU',
                                            value: double.parse(sysInfo.cpuUsage) / 100,
                                            color: _getUsageColor(double.parse(sysInfo.cpuUsage)),
                                            showPercentage: true,
                                            percentage: '${sysInfo.cpuUsage}%',
                                          ),
                                          const SizedBox(height: 12),
                                          _buildLinearProgressBar(
                                            label: 'RAM',
                                            value: double.parse(sysInfo.ramUsage) / 100,
                                            color: _getUsageColor(double.parse(sysInfo.ramUsage)),
                                            showPercentage: true,
                                            percentage: '${sysInfo.ramUsage}%',
                                          ),
                                          const SizedBox(height: 12),
                                          _buildLinearProgressBar(
                                            label: 'Disk',
                                            value: double.parse(sysInfo.diskUsage) / 100,
                                            color: _getUsageColor(double.parse(sysInfo.diskUsage)),
                                            showPercentage: true,
                                            percentage: '${sysInfo.diskUsage}%',
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSystemInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      color: AppTheme.darkBackground,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLinearProgressBar({
    required String label,
    required double value,
    required Color color,
    bool showPercentage = false,
    String? percentage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            if (showPercentage && percentage != null)
              Text(
                percentage,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: AppTheme.darkSurface,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp >= 75) {
      return AppTheme.error;
    } else if (temp >= 65) {
      return AppTheme.warning;
    } else {
      return AppTheme.online;
    }
  }

  Color _getUsageColor(double percentage) {
    if (percentage >= 90) {
      return AppTheme.error;
    } else if (percentage >= 70) {
      return AppTheme.warning;
    } else {
      return AppTheme.online;
    }
  }
}
