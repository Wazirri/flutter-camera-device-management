import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';

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
      body: Consumer<CameraDevicesProvider>(
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
              return DeviceCard(
                device: device,
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

  const DeviceCard({
    Key? key,
    required this.device,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPrint('DeviceCard build START for ${device.macAddress}');
    final theme = Theme.of(context);
    final provider = Provider.of<CameraDevicesProvider>(context, listen: false);

    // Determine status text and color
    String statusText;
    Color statusColor;

    // Access status via the getter, which now includes logging
    final currentStatus = device.status; 
    debugPrint('DeviceCard build: ${device.macAddress}, connected: ${device.connected}, online: ${device.online}, firstTime: ${device.firstTime}, status from getter: $currentStatus'); // MODIFIED

    switch (currentStatus) {
      case DeviceStatus.online:
        statusText = 'Online';
        statusColor = Colors.green;
        break;
      case DeviceStatus.offline:
        statusText = 'Offline';
        statusColor = Colors.red;
        break;
      case DeviceStatus.warning:
        statusText = 'Warning';
        statusColor = Colors.orange;
        break;
      default:
        statusText = 'Unknown';
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: device.connected 
              ? AppTheme.primaryColor
              : Theme.of(context).dividerColor,
          width: device.connected ? 2 : 1,
        ),
      ),
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
                  Text(
                    device.deviceType.isEmpty 
                        ? 'Device ${device.macAddress}' 
                        : device.deviceType,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
    debugPrint('DeviceDetailsSheet build START for ${device.macAddress}');
    final theme = Theme.of(context);

    // Determine status text and color
    String statusText;
    Color statusColor;
    
    final currentStatus = device.status; // Access status via the getter
    debugPrint('DeviceDetailsSheet build: ${device.macAddress}, connected: ${device.connected}, online: ${device.online}, firstTime: ${device.firstTime}, status from getter: $currentStatus'); // MODIFIED

    switch (currentStatus) {
      case DeviceStatus.online:
        statusText = 'Online';
        statusColor = Colors.green;
        break;
      case DeviceStatus.offline:
        statusText = 'Offline';
        statusColor = Colors.red;
        break;
      case DeviceStatus.warning:
        statusText = 'Warning';
        statusColor = Colors.orange;
        break;
      default:
        statusText = 'Unknown';
        statusColor = Colors.grey;
    }

    return Column(
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
        const Divider(),
        // Device Info
        Padding(
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
              InfoRow(label: 'IP Address', value: device.ipv4),
              InfoRow(label: 'Last Seen', value: device.lastSeenAt),
              InfoRow(label: 'Uptime', value: device.formattedUptime),
              InfoRow(label: 'Firmware', value: device.firmwareVersion),
              InfoRow(label: 'Record Path', value: device.recordPath),
            ],
          ),
        ),
        const Divider(),
        // Cameras List
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
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
                    // TODO: Navigate to live view screen with all cameras from this device
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/live-view');
                  },
                ),
            ],
          ),
        ),
        // Camera Cards
        Expanded(
          child: device.cameras.isEmpty
              ? const Center(
                  child: Text('No cameras found for this device'),
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: device.cameras.length,
                  itemBuilder: (context, index) {
                    final camera = device.cameras[index];
                    return CameraCard(
                      camera: camera,
                      onTap: () {
                        // Set the selected camera
                        Provider.of<CameraDevicesProvider>(context, listen: false)
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