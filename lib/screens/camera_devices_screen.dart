import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/websocket_service.dart';
import '../models/camera_device.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/status_indicator.dart';
import '../theme/app_theme.dart';
import '../helpers/responsive_helper.dart';

class CameraDevicesScreen extends StatefulWidget {
  const CameraDevicesScreen({Key? key}) : super(key: key);

  @override
  State<CameraDevicesScreen> createState() => _CameraDevicesScreenState();
}

class _CameraDevicesScreenState extends State<CameraDevicesScreen> {
  String _selectedDeviceMAC = '';
  String _selectedCameraName = '';
  int _selectedTab = 0;
  
  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final WebSocketService webSocketService = Provider.of<WebSocketService>(context);
    final devices = webSocketService.devicesList;
    final allCameras = webSocketService.allCameras;
    final onlineCameras = webSocketService.onlineCameras;
    final recordingCameras = webSocketService.recordingCameras;
    
    // Select the first device if none selected
    if (_selectedDeviceMAC.isEmpty && devices.isNotEmpty) {
      _selectedDeviceMAC = devices.first.macAddress;
    }
    
    // Get selected device
    DeviceInfo? selectedDevice;
    if (devices.isNotEmpty) {
      selectedDevice = devices.firstWhere(
        (d) => d.macAddress == _selectedDeviceMAC,
        orElse: () => devices.first,
      );
      
      // Select first camera if none selected
      if (_selectedCameraName.isEmpty && selectedDevice.cameras.isNotEmpty) {
        _selectedCameraName = selectedDevice.cameras.first.name;
      }
    }
    
    // Get selected camera
    CameraDevice? selectedCamera;
    if (selectedDevice != null && selectedDevice.cameras.isNotEmpty) {
      selectedCamera = selectedDevice.cameras.firstWhere(
        (c) => c.name == _selectedCameraName,
        orElse: () => selectedDevice.cameras.first,
      );
    }
    
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: CustomAppBar(
        title: 'Camera Devices',
        isDesktop: isDesktop,
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Go to Live View',
            onPressed: () {
              Navigator.pushNamed(context, '/live-view');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: webSocketService.isInitialized
          ? Row(
              children: [
                // Devices list sidebar
                if (isDesktop || ResponsiveHelper.isTablet(context))
                  SizedBox(
                    width: 280,
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: AppTheme.darkSurface,
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Column(
                        children: [
                          // Devices header
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Devices',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkTextPrimary,
                                  ),
                                ),
                                Text(
                                  '${devices.length} found',
                                  style: const TextStyle(
                                    color: AppTheme.darkTextSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Device list
                          Expanded(
                            child: ListView.builder(
                              itemCount: devices.length,
                              itemBuilder: (context, index) {
                                final device = devices[index];
                                return _buildDeviceListItem(
                                  device: device,
                                  isSelected: device.macAddress == _selectedDeviceMAC,
                                  onTap: () {
                                    setState(() {
                                      _selectedDeviceMAC = device.macAddress;
                                      if (device.cameras.isNotEmpty) {
                                        _selectedCameraName = device.cameras.first.name;
                                      } else {
                                        _selectedCameraName = '';
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                // Main content area
                Expanded(
                  child: Column(
                    children: [
                      // Navigation tabs
                      Container(
                        color: AppTheme.darkSurface,
                        child: TabBar(
                          onTap: (index) {
                            setState(() {
                              _selectedTab = index;
                            });
                          },
                          labelColor: AppTheme.primaryBlue,
                          unselectedLabelColor: AppTheme.darkTextSecondary,
                          indicatorColor: AppTheme.primaryBlue,
                          tabs: [
                            Tab(
                              text: selectedDevice != null 
                                  ? 'Device Info (${selectedDevice.macAddress})' 
                                  : 'Device Info',
                            ),
                            Tab(
                              text: allCameras.isNotEmpty 
                                  ? 'All Cameras (${allCameras.length})' 
                                  : 'All Cameras',
                            ),
                            Tab(
                              text: 'Online (${onlineCameras.length})',
                            ),
                            Tab(
                              text: 'Recording (${recordingCameras.length})',
                            ),
                          ],
                        ),
                      ),
                      
                      // Content based on selected tab
                      Expanded(
                        child: _selectedTab == 0
                            ? _buildDeviceInfoTab(selectedDevice, selectedCamera)
                            : _selectedTab == 1
                                ? _buildCamerasListTab(allCameras)
                                : _selectedTab == 2
                                    ? _buildCamerasListTab(onlineCameras)
                                    : _buildCamerasListTab(recordingCameras),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading device data...',
                    style: TextStyle(color: AppTheme.darkTextPrimary),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please ensure you are connected to WebSocket',
                    style: TextStyle(color: AppTheme.darkTextSecondary),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildDeviceListItem({
    required DeviceInfo device,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppTheme.primaryBlue.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Icon(
            Icons.devices,
            color: device.isConnected ? AppTheme.primaryBlue : AppTheme.darkTextSecondary,
            size: 20,
          ),
        ),
      ),
      title: Text(
        device.deviceType.isNotEmpty ? device.deviceType : device.macAddress,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryBlue : AppTheme.darkTextPrimary,
        ),
      ),
      subtitle: Row(
        children: [
          StatusIndicator(
            status: device.isConnected ? DeviceStatus.online : DeviceStatus.offline,
            size: 8,
          ),
          const SizedBox(width: 4),
          Text(
            '${device.cameras.length} cameras${device.hasError ? ' | Error' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: device.hasError ? AppTheme.error : AppTheme.darkTextSecondary,
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: isSelected ? AppTheme.primaryBlue : AppTheme.darkTextSecondary,
      ),
      onTap: onTap,
    );
  }
  
  Widget _buildDeviceInfoTab(DeviceInfo? device, CameraDevice? selectedCamera) {
    if (device == null) {
      return const Center(
        child: Text('No device selected', style: TextStyle(color: AppTheme.darkTextSecondary)),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device info card
          Card(
            color: AppTheme.darkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device header
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.devices,
                            color: AppTheme.primaryBlue,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.deviceType.isNotEmpty ? device.deviceType : 'Device',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkTextPrimary,
                              ),
                            ),
                            Row(
                              children: [
                                StatusIndicator(
                                  status: device.isConnected ? DeviceStatus.online : DeviceStatus.offline,
                                  size: 8,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  device.isConnected ? 'Online' : 'Offline',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.darkTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Device details
                  const Text(
                    'Device Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  _buildInfoRow('MAC Address', device.macAddress),
                  _buildInfoRow('IPv4', device.ipv4),
                  _buildInfoRow('IPv6', device.ipv6),
                  _buildInfoRow('First Seen', device.firstSeen),
                  _buildInfoRow('Last Seen', device.lastSeen),
                  _buildInfoRow('Uptime', device.uptime),
                  _buildInfoRow('Firmware', device.firmwareVersion),
                  _buildInfoRow('Has Error', device.hasError ? 'Yes' : 'No'),
                  _buildInfoRow('Cameras', '${device.cameras.length}'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Device cameras section
          Text(
            'Cameras (${device.cameras.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Camera selection tabs
          if (device.cameras.isNotEmpty) ...[
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: device.cameras.length,
                itemBuilder: (context, index) {
                  final camera = device.cameras[index];
                  final isSelected = camera.name == _selectedCameraName;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCameraName = camera.name;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryBlue : AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Row(
                          children: [
                            StatusIndicator(
                              status: camera.isConnected ? DeviceStatus.online : DeviceStatus.offline,
                              size: 8,
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              camera.name,
                              style: TextStyle(
                                fontSize: 14,
                                color: isSelected ? Colors.white : AppTheme.darkTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Selected camera details
            if (selectedCamera != null)
              _buildSelectedCameraDetails(selectedCamera)
            else
              const Text(
                'No camera selected',
                style: TextStyle(color: AppTheme.darkTextSecondary),
              ),
          ] else
            const Text(
              'No cameras found for this device',
              style: TextStyle(color: AppTheme.darkTextSecondary),
            ),
        ],
      ),
    );
  }
  
  Widget _buildSelectedCameraDetails(CameraDevice camera) {
    return Card(
      color: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera header with action buttons
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: camera.isConnected
                        ? AppTheme.primaryBlue.withOpacity(0.1)
                        : AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      camera.isConnected ? Icons.videocam : Icons.videocam_off,
                      color: camera.isConnected ? AppTheme.primaryBlue : AppTheme.error,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          StatusIndicator(
                            status: camera.isConnected ? DeviceStatus.online : DeviceStatus.offline,
                            size: 8,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            camera.isConnected ? 'Connected' : 'Disconnected',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.darkTextSecondary,
                            ),
                          ),
                          if (camera.isRecording) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.fiber_manual_record,
                                    color: AppTheme.error,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Recording',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Camera details
            const Text(
              'Camera Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow('IP Address', camera.cameraIp),
            _buildInfoRow('Brand', camera.brand),
            _buildInfoRow('Model', camera.model),
            _buildInfoRow('Resolution', '${camera.width}x${camera.height}'),
            _buildInfoRow('Codec', camera.codec),
            _buildInfoRow('Last Seen', camera.lastSeenAt),
            _buildInfoRow('RTSP URI', camera.rtspUri),
            _buildInfoRow('Snapshot URI', camera.snapshotUri),
            _buildInfoRow('Recording', camera.isRecording ? 'Yes' : 'No'),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.videocam),
                  label: const Text('View Live'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/live-view');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCamerasListTab(List<CameraDevice> cameras) {
    if (cameras.isEmpty) {
      return const Center(
        child: Text('No cameras found', style: TextStyle(color: AppTheme.darkTextSecondary)),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${cameras.length} Cameras',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Grid of cameras
          ResponsiveHelper.isDesktop(context)
              ? _buildCamerasGrid(cameras, 3)
              : ResponsiveHelper.isTablet(context)
                  ? _buildCamerasGrid(cameras, 2)
                  : _buildCamerasList(cameras),
        ],
      ),
    );
  }
  
  Widget _buildCamerasGrid(List<CameraDevice> cameras, int crossAxisCount) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: cameras.length,
      itemBuilder: (context, index) {
        return _buildCameraCard(cameras[index]);
      },
    );
  }
  
  Widget _buildCamerasList(List<CameraDevice> cameras) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cameras.length,
      itemBuilder: (context, index) {
        return _buildCameraListItem(cameras[index]);
      },
    );
  }
  
  Widget _buildCameraCard(CameraDevice camera) {
    return Card(
      color: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      camera.isConnected ? Icons.videocam : Icons.videocam_off,
                      color: camera.isConnected ? AppTheme.primaryBlue : AppTheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      camera.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkTextPrimary,
                      ),
                    ),
                  ],
                ),
                if (camera.isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: AppTheme.error,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'REC',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Device info
            Text(
              'Device: ${camera.macAddress}',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            
            // Resolution
            Text(
              'Resolution: ${camera.width}x${camera.height}',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            
            // Status
            Row(
              children: [
                StatusIndicator(
                  status: camera.isConnected ? DeviceStatus.online : DeviceStatus.offline,
                  size: 8,
                ),
                const SizedBox(width: 4),
                Text(
                  camera.isConnected ? 'Connected' : 'Disconnected',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkTextSecondary,
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // View button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/live-view');
                },
                icon: const Icon(Icons.visibility),
                label: const Text('View Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCameraListItem(CameraDevice camera) {
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: camera.isConnected
                ? AppTheme.primaryBlue.withOpacity(0.1)
                : AppTheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Icon(
              camera.isConnected ? Icons.videocam : Icons.videocam_off,
              color: camera.isConnected ? AppTheme.primaryBlue : AppTheme.error,
              size: 20,
            ),
          ),
        ),
        title: Text(
          camera.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkTextPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device: ${camera.macAddress}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            Row(
              children: [
                StatusIndicator(
                  status: camera.isConnected ? DeviceStatus.online : DeviceStatus.offline,
                  size: 8,
                ),
                const SizedBox(width: 4),
                Text(
                  camera.isConnected ? 'Connected' : 'Disconnected',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkTextSecondary,
                  ),
                ),
                if (camera.isRecording) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: AppTheme.error,
                          size: 10,
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          'REC',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/live-view');
          },
          child: const Text('View'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}