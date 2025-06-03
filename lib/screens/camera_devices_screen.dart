import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Added import for DateFormat

import '../models/camera_device.dart';
import '../providers/camera_devices_provider_optimized.dart';
import '../theme/app_theme.dart'; // Fixed import for AppTheme
// Removed app_localizations import to fix build error

class CameraDevicesScreen extends StatefulWidget {
  const CameraDevicesScreen({Key? key}) : super(key: key);

  @override
  State<CameraDevicesScreen> createState() => _CameraDevicesScreenState();
}

class _CameraDevicesScreenState extends State<CameraDevicesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Devices'),
        backgroundColor: AppTheme.darkBackground,
      ),
      body: Consumer<CameraDevicesProviderOptimized>(
        builder: (context, provider, child) {
          final devices = provider.devicesList;
          
          if (devices.isEmpty) {
            return const Center(
              child: Text(
                'No camera devices found.\nMake sure you are connected to the server.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final isSelected = provider.selectedDevice?.macKey == device.macKey;
              return DeviceCard(
                device: device,
                isSelected: isSelected,
                onTap: () {
                  provider.setSelectedDevice(device.macKey);
                  _showDeviceDetails(context, device);
                },
              );
            },
          );
        },
      ),
    );
  }
  
  void _showDeviceDetails(BuildContext context, CameraDevice device) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return DeviceDetailsSheet(
              device: device,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
}

class DeviceCard extends StatelessWidget {
  final CameraDevice device;
  final VoidCallback onTap;
  final bool isSelected;

  const DeviceCard({
    Key? key,
    required this.device,
    required this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('DeviceCard build START for ${device.macAddress}');

    // Access status via the getter, which now includes logging
    final currentStatus = device.status; 
    print('DeviceCard build: ${device.macAddress}, connected: ${device.connected}, online: ${device.online}, firstTime: ${device.firstTime}, status from getter: $currentStatus'); // MODIFIED

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isSelected ? 8 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected 
              ? AppTheme.primaryColor.withOpacity(0.8)
              : (device.connected 
                  ? AppTheme.primaryColor
                  : Theme.of(context).dividerColor),
          width: isSelected ? 3 : (device.connected ? 2 : 1),
        ),
      ),
      color: isSelected 
          ? AppTheme.primaryColor.withOpacity(0.1)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (isSelected) ...[
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            device.deviceType.isEmpty 
                                ? 'Device ${device.macAddress}' 
                                : device.deviceType,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.primaryColor : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: device.connected
                          ? AppTheme.primaryColor
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      // Use device.status to determine online/offline text
                      device.status == DeviceStatus.online ? 'Online' : 
                      (device.status == DeviceStatus.warning ? 'Warning' : 'Offline'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'MAC: ${device.macAddress}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'IP: ${device.ipv4}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cameras: ${device.cameras.length}',
                style: const TextStyle(fontSize: 14),
              ),
              if (device.uptime.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Uptime: ${device.formattedUptime}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              if (device.firmwareVersion.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Firmware: ${device.firmwareVersion}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              // ADDED: Explicit display for device.online and device.connected
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(
                    device.online ? Icons.power_settings_new : Icons.power_off,
                    color: device.online ? AppTheme.online : AppTheme.offline,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Powered: ${device.online ? "On" : "Off"}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.darkTextSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4), // Space between the two new rows
              Row(
                children: <Widget>[
                  Icon(
                    device.connected ? Icons.link : Icons.link_off,
                    color: device.connected ? AppTheme.online : AppTheme.offline,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connection: ${device.connected ? "Active" : "Inactive"}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.darkTextSecondary),
                  ),
                ],
              ),
              // END ADDED
              const SizedBox(height: 8),
              Text(
                'Last seen: ${device.lastSeenAt}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceDetailsSheet extends StatelessWidget {
  final CameraDevice device;
  final ScrollController scrollController;

  const DeviceDetailsSheet({
    Key? key,
    required this.device,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('DeviceDetailsSheet build START for ${device.macAddress}');
    
    final currentStatus = device.status; // Access status via the getter
    print('DeviceDetailsSheet build: ${device.macAddress}, connected: ${device.connected}, online: ${device.online}, firstTime: ${device.firstTime}, status from getter: $currentStatus'); // MODIFIED

    return DefaultTabController(
      length: 2, // İki tab için: Cihaz Bilgileri ve Kameralar
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceType.isEmpty 
                            ? 'Device ${device.macAddress}' 
                            : device.deviceType,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MAC: ${device.macAddress}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: device.connected
                        ? AppTheme.primaryColor
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    // Use device.status to determine online/offline text
                    device.status == DeviceStatus.online ? 'Online' : 
                    (device.status == DeviceStatus.warning ? 'Warning' : 'Offline'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Bar
          TabBar(
            tabs: const [
              Tab(
                icon: Icon(Icons.info_outline),
                text: 'Device Info',
              ),
              Tab(
                icon: Icon(Icons.videocam_outlined),
                text: 'Cameras',
              ),
            ],
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
          ),
          
          // Tab Bar View
          Expanded(
            child: TabBarView(
              children: [
                // İlk Tab: Cihaz Bilgileri
                SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Device Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Temel Bilgiler
                      InfoRow(label: 'Device Name', value: device.deviceName ?? 'Unknown'),
                      InfoRow(label: 'IP Address (IPv4)', value: device.ipv4),
                      if (device.ipv6 != null && device.ipv6!.isNotEmpty)
                        InfoRow(label: 'IP Address (IPv6)', value: device.ipv6!),
                      InfoRow(label: 'MAC Address', value: device.macAddress),
                      InfoRow(label: 'First Seen', value: device.firstTime),
                      InfoRow(label: 'Last Seen', value: device.lastSeenAt),
                      InfoRow(label: 'Current Time', value: device.currentTime ?? 'Unknown'),
                      InfoRow(label: 'Uptime', value: device.formattedUptime),
                      InfoRow(label: 'Firmware Version', value: device.firmwareVersion),
                      if (device.smartwebVersion != null && device.smartwebVersion!.isNotEmpty)
                        InfoRow(label: 'SmartWeb Version', value: device.smartwebVersion!),
                      InfoRow(
                        label: 'CPU Temperature', 
                        value: device.cpuTemp > 0 ? '${device.cpuTemp.toStringAsFixed(1)}°C' : 'Not available'
                      ),
                      InfoRow(label: 'Master Status', value: device.isMaster == true ? 'Master' : 'Slave'),
                      InfoRow(label: 'Last Timestamp', value: device.lastTs ?? 'Unknown'),
                      InfoRow(label: 'Record Path', value: device.recordPath),
                      InfoRow(label: 'Camera Count', value: '${device.camCount}'),
                      InfoRow(
                        label: 'Total RAM', 
                        value: device.totalRam > 0 ? '${(device.totalRam / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB' : 'Not available'
                      ),
                      InfoRow(
                        label: 'Free RAM', 
                        value: device.freeRam > 0 ? '${(device.freeRam / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB' : 'Not available'
                      ),
                      InfoRow(label: 'Network Info', value: device.networkInfo ?? 'Unknown'),
                      InfoRow(label: 'Total Connections', value: '${device.totalConnections}'),
                      InfoRow(label: 'Total Sessions', value: '${device.totalSessions}'),
                      
                      // Powered ve Connection status
                      const SizedBox(height: 16),
                      const Text(
                        'Status Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SizedBox(
                              width: 100,
                              child: Text(
                                'Powered',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Icon(
                              device.online ? Icons.power_settings_new : Icons.power_off,
                              color: device.online ? AppTheme.online : AppTheme.offline,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                device.online ? "On" : "Off",
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SizedBox(
                              width: 100,
                              child: Text(
                                'Connection',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Icon(
                              device.connected ? Icons.link : Icons.link_off,
                              color: device.connected ? AppTheme.online : AppTheme.offline,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                device.connected ? "Active" : "Inactive",
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // İkinci Tab: Kameralar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cameras (${device.cameras.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (device.cameras.isNotEmpty && device.connected)
                            TextButton.icon(
                              icon: const Icon(Icons.visibility),
                              label: const Text('View All'),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/live-view');
                              },
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: device.cameras.isEmpty
                          ? const Center(
                              child: Text('No cameras found for this device'),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: device.cameras.length,
                              itemBuilder: (context, index) {
                                final camera = device.cameras[index];
                                return CameraCard(
                                  camera: camera,
                                  onTap: () {
                                    // Set the selected camera
                                    Provider.of<CameraDevicesProviderOptimized>(context, listen: false)
                                        .setSelectedCameraIndex(index);
                                        
                                    // Navigate to live view screen
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context, '/live-view');
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  
  const InfoRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
  }
}

class CameraCard extends StatelessWidget {
  final Camera camera;
  final VoidCallback onTap;
  
  const CameraCard({
    Key? key,
    required this.camera,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: camera.connected 
              ? camera.recording
                  ? Colors.red
                  : AppTheme.accentColor
              : Theme.of(context).dividerColor,
          width: camera.connected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      camera.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // Recording indicator
                      if (camera.recording)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.fiber_manual_record,
                                size: 12,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'REC',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: camera.connected 
                              ? AppTheme.accentColor 
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          camera.connected ? 'Online' : 'Offline',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'IP: ${camera.ip}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Model: ${camera.brand} ${camera.hw}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.videocam,
                    size: 16,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Resolution: ${camera.recordWidth}x${camera.recordHeight}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Last seen: ${camera.lastSeenAt}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}