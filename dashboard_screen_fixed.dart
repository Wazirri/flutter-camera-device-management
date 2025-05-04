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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
    
    return GridView.count(
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
              child: const Row(
                children: [
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
              child: const Row(
                children: [
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

  Widget _buildSystemInfoSection(BuildContext context, WebSocketProvider websocketProvider) {
    // Get system info from websocket provider
    final systemInfo = websocketProvider.systemInfo;
    
    return Card(
      color: AppTheme.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.computer_rounded, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Text(
                  'System Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Wrap in Consumer to rebuild when system info changes
            Consumer<WebSocketProvider>(
              builder: (context, provider, child) {
                final systemInfo = provider.systemInfo;
                
                return Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _buildSystemInfoItem('RAM Usage', 
                      systemInfo != null 
                        ? '${systemInfo.ramUsagePercentage.toStringAsFixed(1)}%' 
                        : 'N/A',
                      Icons.memory_rounded),
                    _buildSystemInfoItem('CPU Temp', 
                      systemInfo != null 
                        ? systemInfo.formattedCpuTemp
                        : 'N/A',
                      Icons.thermostat_rounded),
                    _buildSystemInfoItem('RAM', 
                      systemInfo != null 
                        ? systemInfo.formattedFreeRam
                        : 'N/A',
                      Icons.storage_rounded),
                    _buildSystemInfoItem('Uptime', 
                      systemInfo != null 
                        ? systemInfo.formattedUpTime
                        : 'N/A',
                      Icons.access_time_rounded),
                    _buildSystemInfoItem('GPU Temp', 
                      systemInfo != null 
                        ? systemInfo.gpuThermal
                        : 'N/A',
                      Icons.disc_full_rounded),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfoItem(String label, String value, IconData icon) {
    // Extract numeric value from percentage strings for progress indicator
    double percentValue = 0.0;
    if (value.contains('%')) {
      try {
        percentValue = double.parse(value.replaceAll('%', '').trim()) / 100.0;
        if (percentValue > 1.0) percentValue = 1.0;
        if (percentValue < 0.0) percentValue = 0.0;
      } catch (e) {
        percentValue = 0.0;
      }
    }
    
    bool hasProgressBar = label.toLowerCase().contains('usage') || 
                          label.toLowerCase().contains('temp') ||
                          label.toLowerCase().contains('cpu') ||
                          label.toLowerCase().contains('gpu');
    
    // Color logic for indicators
    Color indicatorColor = AppTheme.primaryBlue;
    if (percentValue > 0.8) {
      indicatorColor = AppTheme.error;
    } else if (percentValue > 0.6) {
      indicatorColor = AppTheme.warning;
    }
    
    // If it's a temperature value (contains °C)
    if (value.contains('°C')) {
      try {
        double tempValue = double.parse(value.replaceAll('°C', '').trim());
        percentValue = tempValue / 100.0; // Assuming max temp is 100°C
        if (percentValue > 1.0) percentValue = 1.0;
        
        if (tempValue > 75) {
          indicatorColor = AppTheme.error;
        } else if (tempValue > 60) {
          indicatorColor = AppTheme.warning;
        }
      } catch (e) {
        percentValue = 0.0;
      }
    }
    
    return Container(
      width: 220,
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: AppTheme.darkSurface.withOpacity(0.7),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                      icon,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.darkTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasProgressBar) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentValue,
                    backgroundColor: AppTheme.darkBackground,
                    valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatUptime(int seconds) {
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (days > 0) {
      return '$days d ${hours}h';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}