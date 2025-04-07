import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/device_status.dart';
import '../providers/websocket_provider.dart';
import '../models/system_info.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/status_indicator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with AutomaticKeepAliveClientMixin {
  SystemInfo? _systemInfo;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Initial system info fetch
    _fetchSystemInfo();
  }

  void _fetchSystemInfo() {
    final webSocketProvider = Provider.of<WebSocketProvider>(context, listen: false);
    webSocketProvider.sendMessage('DO MONITORECS');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final webSocketProvider = Provider.of<WebSocketProvider>(context);
    
    // Process the last message if it's a system info message
    if (webSocketProvider.lastMessage != null && 
        webSocketProvider.lastMessage!.contains('"c":"sysinfo"')) {
      try {
        _systemInfo = SystemInfo.fromJson(webSocketProvider.lastMessage!);
      } catch (e) {
        print('Error parsing system info: $e');
      }
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh System Info',
            onPressed: _fetchSystemInfo,
          ),
        ],
      ),
      body: _systemInfo != null
          ? _buildDashboard()
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text('Waiting for system information...'),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    onPressed: _fetchSystemInfo,
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildDashboard() {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return RefreshIndicator(
      onRefresh: () async {
        _fetchSystemInfo();
        // Wait a bit to simulate refresh
        await Future.delayed(const Duration(seconds: 1));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        child: isDesktop
            ? _buildDesktopLayout()
            : _buildMobileLayout(),
      ),
    );
  }
  
  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Overview Section
          _buildSectionHeader('System Overview', Icons.computer),
          const SizedBox(height: 16),
          
          // Top cards row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildSystemCard(),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildCpuCard(),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildMemoryCard(),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Storage and Network Section
          _buildSectionHeader('Storage & Network', Icons.storage),
          const SizedBox(height: 16),
          
          // Second row with storage and network
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildStorageCard(),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildNetworkCard(),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Devices Section
          _buildSectionHeader('Connected Devices', Icons.devices),
          const SizedBox(height: 16),
          
          // Mock devices for demonstration
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: _buildDeviceCard(
                  title: 'IP Cameras',
                  deviceCount: 12,
                  activeCount: 10,
                  icon: Icons.videocam,
                  iconColor: AppTheme.accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildDeviceCard(
                  title: 'NVR Systems',
                  deviceCount: 3,
                  activeCount: 2,
                  icon: Icons.video_library,
                  iconColor: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildDeviceCard(
                  title: 'Sensors',
                  deviceCount: 8,
                  activeCount: 8,
                  icon: Icons.sensors,
                  iconColor: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildDeviceCard(
                  title: 'Alarms',
                  deviceCount: 4,
                  activeCount: 4,
                  icon: Icons.notification_important,
                  iconColor: Colors.red,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // System Event Logs (Mock data)
          _buildSectionHeader('Recent System Events', Icons.history),
          const SizedBox(height: 16),
          
          _buildRecentEvents(),
        ],
      ),
    );
  }
  
  Widget _buildMobileLayout() {
    return ListView(
      children: [
        // System Overview Section
        _buildSectionHeader('System Overview', Icons.computer),
        const SizedBox(height: 16),
        
        // System card
        _buildSystemCard(),
        const SizedBox(height: 16),
        
        // CPU card
        _buildCpuCard(),
        const SizedBox(height: 16),
        
        // Memory card
        _buildMemoryCard(),
        const SizedBox(height: 24),
        
        // Storage and Network Section
        _buildSectionHeader('Storage & Network', Icons.storage),
        const SizedBox(height: 16),
        
        // Storage card
        _buildStorageCard(),
        const SizedBox(height: 16),
        
        // Network card
        _buildNetworkCard(),
        const SizedBox(height: 24),
        
        // Devices Section
        _buildSectionHeader('Connected Devices', Icons.devices),
        const SizedBox(height: 16),
        
        // Device cards
        _buildDeviceCard(
          title: 'IP Cameras',
          deviceCount: 12,
          activeCount: 10,
          icon: Icons.videocam,
          iconColor: AppTheme.accentColor,
        ),
        const SizedBox(height: 16),
        
        _buildDeviceCard(
          title: 'NVR Systems',
          deviceCount: 3,
          activeCount: 2,
          icon: Icons.video_library,
          iconColor: Colors.green,
        ),
        const SizedBox(height: 16),
        
        _buildDeviceCard(
          title: 'Sensors',
          deviceCount: 8,
          activeCount: 8,
          icon: Icons.sensors,
          iconColor: Colors.orange,
        ),
        const SizedBox(height: 16),
        
        _buildDeviceCard(
          title: 'Alarms',
          deviceCount: 4,
          activeCount: 4,
          icon: Icons.notification_important,
          iconColor: Colors.red,
        ),
        const SizedBox(height: 24),
        
        // System logs section
        _buildSectionHeader('Recent System Events', Icons.history),
        const SizedBox(height: 16),
        
        _buildRecentEvents(),
      ],
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppTheme.accentColor,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSystemCard() {
    final uptime = _systemInfo!.upTime;
    final days = uptime ~/ (24 * 60 * 60);
    final hours = (uptime - (days * 24 * 60 * 60)) ~/ 3600;
    final minutes = (uptime - (days * 24 * 60 * 60) - (hours * 3600)) ~/ 60;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // System icon
                CircleAvatar(
                  backgroundColor: AppTheme.accentColor.withOpacity(0.1),
                  radius: 32,
                  child: Icon(
                    Icons.memory,
                    size: 40,
                    color: AppTheme.accentColor,
                  ),
                ),
                const SizedBox(width: 16),
                // System details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'movita ECS Server',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version: ${_systemInfo!.version}',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          StatusIndicator(
                            status: DeviceStatus.online,
                            showLabel: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // System statistics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.timer,
                  label: 'Uptime',
                  value: '$days days, $hours hours, $minutes min',
                ),
                _buildStatItem(
                  icon: Icons.videocam,
                  label: 'Cameras',
                  value: '${_systemInfo!.cameraCount}',
                ),
                _buildStatItem(
                  icon: Icons.storage,
                  label: 'Recordings',
                  value: '${_systemInfo!.recordingCount}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCpuCard() {
    final cpuTemp = double.tryParse(_systemInfo!.cpuTemp) ?? 0.0;
    final cpuPercent = cpuTemp / 100.0; // Normalize for progress indicator
    
    // Determine status color based on temperature
    final Color statusColor = cpuTemp < 60 
        ? AppTheme.accentColor // Normal - Blue
        : cpuTemp < 80 
            ? AppTheme.primaryColor // Warning - Orange
            : AppTheme.errorColor; // Critical - Red
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'CPU Temperature',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            CircularPercentIndicator(
              radius: 80,
              lineWidth: 12,
              percent: min(cpuPercent, 1.0),
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${cpuTemp.toStringAsFixed(1)}°C',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getTemperatureStatus(cpuTemp),
                    style: TextStyle(
                      fontSize: 14,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              progressColor: statusColor,
              backgroundColor: statusColor.withOpacity(0.2),
              animation: true,
              animationDuration: 1000,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(height: 16),
            Text(
              'CPU Cores: ${_systemInfo!.cpuCores}',
              style: TextStyle(
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getTemperatureStatus(double temp) {
    if (temp < 60) return 'Normal';
    if (temp < 80) return 'Warning';
    return 'Critical';
  }
  
  Widget _buildMemoryCard() {
    final memUsed = double.tryParse(_systemInfo!.memUsed) ?? 0.0;
    final memTotal = double.tryParse(_systemInfo!.memTotal) ?? 1.0;
    final memPercent = memTotal > 0 ? memUsed / memTotal : 0.0;
    
    // Convert to GB for display
    final memUsedGB = memUsed / 1024; // Assuming input is in MB
    final memTotalGB = memTotal / 1024;
    
    // Determine status color based on memory usage
    final Color statusColor = memPercent < 0.7 
        ? AppTheme.accentColor // Normal - Blue
        : memPercent < 0.9 
            ? AppTheme.primaryColor // Warning - Orange
            : AppTheme.errorColor; // Critical - Red
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Memory Usage',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            CircularPercentIndicator(
              radius: 80,
              lineWidth: 12,
              percent: min(memPercent, 1.0),
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(memPercent * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getUsageStatus(memPercent),
                    style: TextStyle(
                      fontSize: 14,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              progressColor: statusColor,
              backgroundColor: statusColor.withOpacity(0.2),
              animation: true,
              animationDuration: 1000,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(height: 16),
            Text(
              '${memUsedGB.toStringAsFixed(1)} GB / ${memTotalGB.toStringAsFixed(1)} GB',
              style: TextStyle(
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getUsageStatus(double percent) {
    if (percent < 0.7) return 'Normal';
    if (percent < 0.9) return 'Warning';
    return 'Critical';
  }
  
  Widget _buildStorageCard() {
    final diskUsed = double.tryParse(_systemInfo!.diskUsed) ?? 0.0;
    final diskTotal = double.tryParse(_systemInfo!.diskTotal) ?? 1.0;
    final diskPercent = diskTotal > 0 ? diskUsed / diskTotal : 0.0;
    
    // Determine status color based on disk usage
    final Color statusColor = diskPercent < 0.7 
        ? AppTheme.accentColor // Normal - Blue
        : diskPercent < 0.9 
            ? AppTheme.primaryColor // Warning - Orange
            : AppTheme.errorColor; // Critical - Red
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storage, size: 20),
                SizedBox(width: 8),
                Text(
                  'Storage Usage',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearPercentIndicator(
              percent: min(diskPercent, 1.0),
              lineHeight: 16,
              animation: true,
              animationDuration: 1000,
              backgroundColor: statusColor.withOpacity(0.2),
              progressColor: statusColor,
              barRadius: const Radius.circular(8),
              padding: EdgeInsets.zero,
              center: Text(
                '${(diskPercent * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Used: ${_formatSize(diskUsed)}',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Total: ${_formatSize(diskTotal)}',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Storage Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStorageDetailItem(
              name: 'System',
              size: diskTotal * 0.1, // Simulated system partition
              total: diskTotal * 0.1,
              icon: Icons.computer,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildStorageDetailItem(
              name: 'Media Storage',
              size: diskUsed * 0.9, // Simulated media storage
              total: diskTotal * 0.9,
              icon: Icons.video_library,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement storage management
              },
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Manage Storage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade800,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatSize(double sizeInGB) {
    if (sizeInGB < 1) {
      return '${(sizeInGB * 1024).toStringAsFixed(0)} MB';
    } else if (sizeInGB < 1024) {
      return '${sizeInGB.toStringAsFixed(1)} GB';
    } else {
      return '${(sizeInGB / 1024).toStringAsFixed(2)} TB';
    }
  }
  
  Widget _buildStorageDetailItem({
    required String name,
    required double size,
    required double total,
    required IconData icon,
    required Color color,
  }) {
    final percent = total > 0 ? size / total : 0.0;
    
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    '${_formatSize(size)} / ${_formatSize(total)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearPercentIndicator(
                percent: min(percent, 1.0),
                lineHeight: 8,
                progressColor: color,
                backgroundColor: color.withOpacity(0.2),
                barRadius: const Radius.circular(4),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildNetworkCard() {
    // Mock network info
    final receivedSpeed = 25.6; // MB/s
    final sentSpeed = 14.2; // MB/s
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.network_check, size: 20),
                SizedBox(width: 8),
                Text(
                  'Network Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildNetworkActivityItem(
                    label: 'Download',
                    value: '$receivedSpeed MB/s',
                    icon: Icons.arrow_downward,
                    color: AppTheme.accentColor,
                    percent: receivedSpeed / 100, // Normalized for visual
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNetworkActivityItem(
                    label: 'Upload',
                    value: '$sentSpeed MB/s',
                    icon: Icons.arrow_upward,
                    color: AppTheme.primaryColor,
                    percent: sentSpeed / 100, // Normalized for visual
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Network Interfaces',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Mock network interface list
            _buildNetworkInterface(
              name: 'Ethernet (eth0)',
              ip: '192.168.1.100',
              status: DeviceStatus.online,
            ),
            const SizedBox(height: 8),
            _buildNetworkInterface(
              name: 'Wi-Fi (wlan0)',
              ip: '192.168.1.101',
              status: DeviceStatus.offline,
            ),
            const SizedBox(height: 8),
            _buildNetworkInterface(
              name: 'VPN (tun0)',
              ip: '10.8.0.5',
              status: DeviceStatus.online,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNetworkActivityItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required double percent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearPercentIndicator(
          percent: min(percent, 1.0),
          lineHeight: 8,
          progressColor: color,
          backgroundColor: color.withOpacity(0.2),
          barRadius: const Radius.circular(4),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildNetworkInterface({
    required String name,
    required String ip,
    required DeviceStatus status,
  }) {
    return Row(
      children: [
        StatusIndicator(
          status: status,
          size: 10,
          showLabel: false,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontSize: 14),
              ),
              Text(
                ip,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDeviceCard({
    required String title,
    required int deviceCount,
    required int activeCount,
    required IconData icon,
    required Color iconColor,
  }) {
    final percent = deviceCount > 0 ? activeCount / deviceCount : 0.0;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '$activeCount / $deviceCount',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Active Devices',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 16),
            LinearPercentIndicator(
              percent: percent,
              lineHeight: 8,
              progressColor: iconColor,
              backgroundColor: iconColor.withOpacity(0.2),
              barRadius: const Radius.circular(4),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                // TODO: Navigate to device type specific screen
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: iconColor,
                side: BorderSide(color: iconColor),
                minimumSize: const Size(double.infinity, 36),
              ),
              child: const Text('View Devices'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.accentColor,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecentEvents() {
    // Mock system event data
    final List<Map<String, dynamic>> events = [
      {
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
        'type': 'info',
        'message': 'System started camera recording for Camera 1',
      },
      {
        'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
        'type': 'warning',
        'message': 'Low disk space detected (15% remaining)',
      },
      {
        'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        'type': 'error',
        'message': 'Connection to Camera 3 lost',
      },
      {
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'type': 'info',
        'message': 'New device connected: NVR System (192.168.1.45)',
      },
      {
        'timestamp': DateTime.now().subtract(const Duration(hours: 3)),
        'type': 'success',
        'message': 'System update completed successfully',
      },
    ];
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: events.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final event = events[index];
                return _buildEventItem(
                  timestamp: event['timestamp'] as DateTime,
                  type: event['type'] as String,
                  message: event['message'] as String,
                );
              },
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  // TODO: Navigate to full log screen
                },
                icon: const Icon(Icons.history, size: 16),
                label: const Text('View All Logs'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEventItem({
    required DateTime timestamp,
    required String type,
    required String message,
  }) {
    IconData icon;
    Color color;
    
    switch (type) {
      case 'info':
        icon = Icons.info;
        color = AppTheme.accentColor;
        break;
      case 'warning':
        icon = Icons.warning;
        color = AppTheme.primaryColor;
        break;
      case 'error':
        icon = Icons.error;
        color = AppTheme.errorColor;
        break;
      case 'success':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      default:
        icon = Icons.circle;
        color = Colors.grey;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}
