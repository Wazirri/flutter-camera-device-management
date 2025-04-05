import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/websocket_provider.dart';
import '../models/system_info.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/status_indicator.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final websocketProvider = Provider.of<WebSocketProvider>(context);
    
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: CustomAppBar(
        title: 'Dashboard',
        isDesktop: isDesktop,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(context),
            const SizedBox(height: 24),
            _buildSystemInfoSection(context, websocketProvider),
            const SizedBox(height: 24),
            _buildOverviewCards(context),
            const SizedBox(height: 24),
            _buildCameraSection(context),
            const SizedBox(height: 24),
            _buildDeviceSection(context),
          ],
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
                  Row(
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
                      const SizedBox(width: 16),
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildDeviceStatusTable(context),
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
            Expanded(
              flex: 3,
              child: Text(
                'Device Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ),
            if (!ResponsiveHelper.isMobile(context))
              Expanded(
                flex: 2,
                child: Text(
                  'Last Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkTextSecondary,
                  ),
                ),
              ),
            Expanded(
              flex: 1,
              child: Container(),
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
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.darkTextPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              type,
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: StatusIndicator(
              status: status,
              showLabel: true,
            ),
          ),
          if (!ResponsiveHelper.isMobile(context))
            Expanded(
              flex: 2,
              child: Text(
                lastActive,
                style: const TextStyle(
                  color: AppTheme.darkTextPrimary,
                ),
              ),
            ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    // No implementation, UI only
                  },
                  color: AppTheme.darkTextSecondary,
                  iconSize: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSystemInfoSection(BuildContext context, WebSocketProvider provider) {
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
                            value: sysInfo.totalConns,
                            icon: Icons.lan_outlined,
                            color: AppTheme.primaryOrange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRamUsageCard(context, sysInfo),
                      const SizedBox(height: 16),
                      _buildThermalAndNetworkCard(context, sysInfo),
                      if (sysInfo.gps['lat'] != '0.000000' || sysInfo.gps['lon'] != '0.000000')
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: _buildGpsCard(context, sysInfo),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSystemInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
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
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRamUsageCard(BuildContext context, SystemInfo sysInfo) {
    final usagePercentage = sysInfo.ramUsagePercentage;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  Icons.memory_outlined,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'RAM Usage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: usagePercentage / 100,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getRamUsageColor(usagePercentage),
              ),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${usagePercentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextPrimary,
                ),
              ),
              Text(
                'Free: ${sysInfo.formattedFreeRam} / Total: ${sysInfo.formattedTotalRam}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildThermalAndNetworkCard(BuildContext context, SystemInfo sysInfo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thermal & Network',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.darkTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.developer_board,
                        color: AppTheme.warning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SOC Thermal',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.darkTextSecondary,
                            ),
                          ),
                          Text(
                            sysInfo.socThermal,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.memory,
                        color: AppTheme.warning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GPU Thermal',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.darkTextSecondary,
                            ),
                          ),
                          Text(
                            sysInfo.gpuThermal,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.online.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.router,
                        color: AppTheme.online,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ETH0',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.darkTextSecondary,
                            ),
                          ),
                          Text(
                            sysInfo.eth0,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.offline.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.network_cell,
                        color: AppTheme.offline,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PPP0',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.darkTextSecondary,
                            ),
                          ),
                          Text(
                            sysInfo.ppp0,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildGpsCard(BuildContext context, SystemInfo sysInfo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.primaryOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'GPS Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.darkTextSecondary,
                      ),
                    ),
                    Text(
                      sysInfo.gpsLocation,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Speed',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  Text(
                    sysInfo.gpsSpeed,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Color _getTemperatureColor(double temp) {
    if (temp >= 75) {
      return Colors.red;
    } else if (temp >= 65) {
      return AppTheme.warning;
    } else {
      return AppTheme.online;
    }
  }
  
  Color _getRamUsageColor(double percentage) {
    if (percentage >= 90) {
      return Colors.red;
    } else if (percentage >= 70) {
      return AppTheme.warning;
    } else {
      return AppTheme.online;
    }
  }
}