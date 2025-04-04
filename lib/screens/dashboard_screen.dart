import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/websocket_provider.dart';
import '../providers/camera_devices_provider.dart';
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
  late WebSocketProvider _websocketProvider;
  late CameraDevicesProvider _cameraDevicesProvider;

  @override
  void initState() {
    super.initState();
    // Schedule this to run after the widget tree has been built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _websocketProvider = Provider.of<WebSocketProvider>(context, listen: false);
      _cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
      
      // Ensure we're connected and system monitoring is active
      if (_websocketProvider.isConnected) {
        _websocketProvider.sendMessage('DO MONITORECS');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    // Listen to WebSocketProvider for changes
    final websocketProvider = Provider.of<WebSocketProvider>(context);
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context);
    
    // Get the current count of cameras and devices
    final cameraCount = cameraDevicesProvider.cameras.length;
    final deviceCount = cameraDevicesProvider.uniqueDeviceCount;
    
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
            _buildOverviewCards(context, cameraCount, deviceCount),
            const SizedBox(height: 24),
            _buildCameraSection(context, cameraDevicesProvider),
            const SizedBox(height: 24),
            _buildDeviceSection(context, cameraDevicesProvider),
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

  Widget _buildOverviewCards(BuildContext context, int cameraCount, int deviceCount) {
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
          value: cameraCount.toString(),
          icon: Icons.camera_alt_rounded,
          color: AppTheme.primaryBlue,
        ),
        _buildStatCard(
          context,
          title: 'Active Devices',
          value: deviceCount.toString(),
          icon: Icons.devices_rounded,
          color: AppTheme.online,
        ),
        _buildStatCard(
          context,
          title: 'Alerts',
          value: '0',
          icon: Icons.warning_amber_rounded,
          color: AppTheme.warning,
        ),
        _buildStatCard(
          context,
          title: 'Recordings',
          value: '0',
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

  Widget _buildCameraSection(BuildContext context, CameraDevicesProvider provider) {
    final cameras = provider.cameras.take(5).toList();
    
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
          child: cameras.isEmpty
              ? const Center(
                  child: Text(
                    'No cameras detected yet',
                    style: TextStyle(color: AppTheme.darkTextSecondary),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: cameras.length,
                  itemBuilder: (context, index) {
                    final camera = cameras[index];
                    return _buildCameraActivityCard(
                      context,
                      name: camera.name ?? 'Camera ${index + 1}',
                      location: camera.brand ?? 'Unknown',
                      timestamp: 'Now',
                      status: DeviceStatus.online,
                      onTap: () {
                        Navigator.pushNamed(
                          context, 
                          '/live-view',
                          arguments: {'camera': camera},
                        );
                      },
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
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
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
                'Connected',
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
                    onPressed: onTap,
                    child: const Text('View Live'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSection(BuildContext context, CameraDevicesProvider provider) {
    final devices = provider.uniqueDevices.take(4).toList();
    
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
                Navigator.pushNamed(context, '/devices');
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
            child: devices.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No devices detected yet',
                        style: TextStyle(color: AppTheme.darkTextSecondary),
                      ),
                    ),
                  )
                : _buildDeviceStatusTable(context, devices),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceStatusTable(BuildContext context, List<String> devices) {
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
          devices.length,
          (index) => _buildDeviceStatusRow(
            context,
            name: devices[index],
            type: 'Camera Device',
            status: DeviceStatus.online,
            lastActive: 'Now',
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
            child: Row(
              children: [
                StatusIndicator(status: status),
                const SizedBox(width: 8),
                Text(
                  status == DeviceStatus.online
                      ? 'Online'
                      : status == DeviceStatus.offline
                          ? 'Offline'
                          : 'Warning',
                  style: const TextStyle(
                    color: AppTheme.darkTextPrimary,
                  ),
                ),
              ],
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
            // Request refresh button
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                if (provider.isConnected) {
                  provider.sendMessage('DO MONITORECS');
                }
              },
              tooltip: 'Refresh system information',
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                      Icons.memory_outlined,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'RAM Usage',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${sysInfo.ramUsagePercentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: sysInfo.ramUsagePercentage / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(_getRamUsageColor(sysInfo.ramUsagePercentage)),
            ),
          ),
          const SizedBox(height: 16),
          isSmallScreen 
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRamInfoItem('Total', sysInfo.formattedTotalRam),
                    const SizedBox(height: 8),
                    _buildRamInfoItem('Free', sysInfo.formattedFreeRam),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildRamInfoItem('Total', sysInfo.formattedTotalRam),
                    _buildRamInfoItem('Free', sysInfo.formattedFreeRam),
                    _buildRamInfoItem('Used', 
                      '${((double.parse(sysInfo.totalRam) - double.parse(sysInfo.freeRam)) / (1024 * 1024)).toStringAsFixed(2)} MB'),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildRamInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkTextPrimary,
          ),
        ),
      ],
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
      child: isSmallScreen
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThermalSection(sysInfo),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildNetworkSection(sysInfo),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildThermalSection(sysInfo),
                ),
                const SizedBox(width: 16),
                const VerticalDivider(width: 1),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNetworkSection(sysInfo),
                ),
              ],
            ),
    );
  }

  Widget _buildThermalSection(SystemInfo sysInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.thermostat_outlined,
              color: AppTheme.warning,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Thermal Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildThermalItem('CPU', sysInfo.formattedCpuTemp),
            if (sysInfo.socThermal != 'N/A')
              _buildThermalItem('SoC', sysInfo.socThermal),
            if (sysInfo.gpuThermal != 'N/A')
              _buildThermalItem('GPU', sysInfo.gpuThermal),
          ],
        ),
      ],
    );
  }

  Widget _buildThermalItem(String label, String value) {
    final temperature = double.tryParse(value.replaceAll('°C', '').trim()) ?? 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getTemperatureColor(temperature).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getTemperatureColor(temperature).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.darkTextSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _getTemperatureColor(temperature),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkSection(SystemInfo sysInfo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.network_check_outlined,
              color: AppTheme.primaryBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Network Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildNetworkItem('Ethernet', sysInfo.eth0),
        const SizedBox(height: 12),
        _buildNetworkItem('PPP', sysInfo.ppp0),
        const SizedBox(height: 12),
        _buildNetworkItem('Active Sessions', sysInfo.sessions),
      ],
    );
  }

  Widget _buildNetworkItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.darkTextSecondary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: value.toLowerCase() == 'unknown' 
                ? Colors.grey.withOpacity(0.2) 
                : AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: value.toLowerCase() == 'unknown' 
                  ? Colors.grey 
                  : AppTheme.primaryBlue,
            ),
          ),
        ),
      ],
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
              Icon(
                Icons.location_on_outlined,
                color: AppTheme.primaryOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'GPS Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
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
                  Text(
                    'Coordinates',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sysInfo.gpsLocation,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Speed',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sysInfo.gpsSpeed,
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

  Color _getTemperatureColor(double temp) {
    if (temp < 50) {
      return AppTheme.online; // Cool
    } else if (temp < 70) {
      return AppTheme.warning; // Warm
    } else {
      return AppTheme.error; // Hot
    }
  }

  Color _getRamUsageColor(double percentage) {
    if (percentage < 60) {
      return AppTheme.online; // Low usage
    } else if (percentage < 85) {
      return AppTheme.warning; // Medium usage
    } else {
      return AppTheme.error; // High usage
    }
  }
}
