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
  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    // Provider değişkenini burada tanımlayalım
    final websocketProvider = Provider.of<WebSocketProvider>(context, listen: false);
    
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
                    'movita ECS - Dashboard',
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
                            Icon(Icons.add_circle_outline_rounded),
                            SizedBox(width: 8),
                            Text('Add Device'),
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
              Image.asset(
                'assets/images/movita_logo.png',
                width: 150,
                height: 150,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context) {
    final isSmallScreen = ResponsiveHelper.isMobile(context);
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isSmallScreen ? 2 : 4,
      childAspectRatio: isSmallScreen ? 1.5 : 2.0,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          context,
          title: 'Online Cameras',
          value: '18',
          icon: Icons.videocam_rounded,
          color: AppTheme.online,
        ),
        _buildStatCard(
          context,
          title: 'Offline Cameras',
          value: '3',
          icon: Icons.videocam_off_rounded,
          color: AppTheme.offline,
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
            const SizedBox(height: 8),
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
                timestamp: '${index + 1}h ago',
                status: index == 2 ? DeviceStatus.offline : DeviceStatus.online,
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
    required String timestamp,
    required DeviceStatus status,
  }) {
    return Card(
      color: AppTheme.darkSurface,
      elevation: 2,
      margin: const EdgeInsets.only(right: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.videocam_rounded,
                      color: AppTheme.darkTextPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkTextPrimary,
                      ),
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
                // No implementation, UI only
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
            child: _buildDeviceTable(context),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceTable(BuildContext context) {
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
    // SystemInfo'yu Consumer ile dinleyerek her değişiklikte yenilenecek
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
            // Consumer widget kullanarak WebSocketProvider'daki her değişikliği dinliyoruz
            child: Consumer<WebSocketProvider>(
              builder: (context, wsProvider, child) {
                final sysInfo = wsProvider.systemInfo;
                final isSmallScreen = ResponsiveHelper.isMobile(context);
                
                if (sysInfo == null) {
                  return const Center(
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
                  );
                }
                
                return Column(
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isSmallScreen ? 3 : 5,
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
                        _buildSystemInfoCard(
                          title: 'Firmware Version',
                          value: sysInfo.version,
                          icon: Icons.system_update_alt,
                          color: AppTheme.primaryBlue,
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
                );
              },
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
    final double usagePercentage = sysInfo.ramUsagePercentage;
    
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
                  Icons.memory_rounded,
                  color: AppTheme.primaryOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'RAM Usage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${usagePercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getRamUsageColor(usagePercentage),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usagePercentage / 100,
              backgroundColor: AppTheme.darkBackground,
              valueColor: AlwaysStoppedAnimation<Color>(_getRamUsageColor(usagePercentage)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Free: ${sysInfo.formattedFreeRam}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
              Text(
                'Total: ${sysInfo.formattedTotalRam}',
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
    final isSmallScreen = ResponsiveHelper.isMobile(context);
    
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.thermostat_rounded,
                            color: AppTheme.warning,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Thermal Sensors',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.darkTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...sysInfo.thermal.map((sensor) {
                      final entry = sensor.entries.first;
                      final name = entry.key;
                      final temp = entry.value;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              name.replaceAll('-thermal', '').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.darkTextPrimary,
                              ),
                            ),
                            Text(
                              '${temp.toStringAsFixed(1)}°C',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _getTemperatureColor(temp),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              if (!isSmallScreen) const SizedBox(width: 24),
              if (!isSmallScreen)
                Expanded(
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
                              Icons.wifi_rounded,
                              color: AppTheme.primaryBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Network Interfaces',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'eth0',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.darkTextPrimary,
                            ),
                          ),
                          Text(
                            sysInfo.eth0 != 'Yok' ? sysInfo.eth0 : 'Disconnected',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: sysInfo.eth0 != 'Yok' ? AppTheme.online : AppTheme.offline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ppp0',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.darkTextPrimary,
                            ),
                          ),
                          Text(
                            sysInfo.ppp0 != 'Yok' ? sysInfo.ppp0 : 'Disconnected',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: sysInfo.ppp0 != 'Yok' ? AppTheme.online : AppTheme.offline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Active Sessions',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.darkTextPrimary,
                            ),
                          ),
                          Text(
                            sysInfo.sessions,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (isSmallScreen) const SizedBox(height: 24),
          if (isSmallScreen)
            Column(
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
                        Icons.wifi_rounded,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Network Interfaces',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.darkTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'eth0',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.darkTextPrimary,
                      ),
                    ),
                    Text(
                      sysInfo.eth0 != 'Yok' ? sysInfo.eth0 : 'Disconnected',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: sysInfo.eth0 != 'Yok' ? AppTheme.online : AppTheme.offline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ppp0',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.darkTextPrimary,
                      ),
                    ),
                    Text(
                      sysInfo.ppp0 != 'Yok' ? sysInfo.ppp0 : 'Disconnected',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: sysInfo.ppp0 != 'Yok' ? AppTheme.online : AppTheme.offline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active Sessions',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.darkTextPrimary,
                      ),
                    ),
                    Text(
                      sysInfo.sessions,
                      style: const TextStyle(
                        fontSize: 14,
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
                  Icons.location_on_rounded,
                  color: AppTheme.primaryOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'GPS Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Coordinates',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${sysInfo.gps['lat']}, ${sysInfo.gps['lon']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Speed',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${sysInfo.gps['speed']} km/h',
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
  
  Color _getTemperatureColor(double temperature) {
    if (temperature < 50) {
      return AppTheme.online;
    } else if (temperature < 70) {
      return AppTheme.warning;
    } else {
      return AppTheme.error;
    }
  }
  
  Color _getRamUsageColor(double percentage) {
    if (percentage < 50) {
      return AppTheme.online;
    } else if (percentage < 80) {
      return AppTheme.warning;
    } else {
      return AppTheme.error;
    }
  }
}

enum DeviceStatus { online, offline, warning }

class StatusIndicator extends StatelessWidget {
  final DeviceStatus status;
  final bool showLabel;
  
  const StatusIndicator({
    Key? key,
    required this.status,
    this.showLabel = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final Color statusColor = _getStatusColor();
    final String statusText = _getStatusText();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 14,
              color: statusColor,
            ),
          ),
        ],
      ],
    );
  }
  
  Color _getStatusColor() {
    switch (status) {
      case DeviceStatus.online:
        return AppTheme.online;
      case DeviceStatus.offline:
        return AppTheme.offline;
      case DeviceStatus.warning:
        return AppTheme.warning;
    }
  }
  
  String _getStatusText() {
    switch (status) {
      case DeviceStatus.online:
        return 'Online';
      case DeviceStatus.offline:
        return 'Offline';
      case DeviceStatus.warning:
        return 'Warning';
    }
  }
}
