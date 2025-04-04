import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_devices_provider.dart';
import '../providers/websocket_provider.dart';
import '../widgets/desktop_side_menu.dart';
import '../widgets/mobile_bottom_navigation_bar.dart';
import '../utils/platform_utils.dart';
import 'cameras_screen.dart';

class CameraDevicesScreen extends StatefulWidget {
  static const String routeName = '/camera-devices';

  const CameraDevicesScreen({Key? key}) : super(key: key);

  @override
  _CameraDevicesScreenState createState() => _CameraDevicesScreenState();
}

class _CameraDevicesScreenState extends State<CameraDevicesScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Request camera information when screen is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDevices();
    });
  }

  // Refresh device list
  Future<void> _refreshDevices() async {
    setState(() {
      _isLoading = true;
    });
    
    // Request camera information from server
    final websocketProvider = Provider.of<WebSocketProvider>(context, listen: false);
    if (websocketProvider.isConnected) {
      websocketProvider.service.requestCameraInfo();
      print('🔄 [CameraDevicesScreen] Requested fresh device data from server');
    } else {
      print('⚠️ [CameraDevicesScreen] Cannot refresh devices - WebSocket not connected');
    }
    
    // Wait a moment for the data to load
    await Future.delayed(Duration(seconds: 1));
    
    // Print device report to debug console
    final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    cameraProvider.debugPrintDevices();
    
    setState(() {
      _isLoading = false;
    });
  }

  void _navigateToDeviceCameras(BuildContext context, String deviceId) {
    // Select the device
    Provider.of<CameraDevicesProvider>(context, listen: false).selectDevice(deviceId);
    
    // Navigate to cameras screen
    Navigator.of(context).pushReplacementNamed(CamerasScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final cameraProvider = Provider.of<CameraDevicesProvider>(context);
    final devices = cameraProvider.devicesList;
    final isDesktop = PlatformUtils.isDesktop();

    return Scaffold(
      appBar: AppBar(
        title: Text('Camera Devices'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshDevices,
            tooltip: 'Refresh Devices',
          ),
        ],
      ),
      body: Row(
        children: [
          // Side menu for desktop platforms
          if (isDesktop) DesktopSideMenu(currentRoute: CameraDevicesScreen.routeName),
          
          // Main content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshDevices,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : devices.isEmpty
                      ? Center(
                          child: Text(
                            'No devices found. Pull to refresh or check your connection.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white60, fontSize: 16),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16.0),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isDesktop ? 3 : 2,
                            childAspectRatio: 1.5,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final device = devices[index];
                            return DeviceCard(
                              device: device,
                              onTap: () => _navigateToDeviceCameras(context, device.macKey),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : MobileBottomNavigationBar(currentRoute: CameraDevicesScreen.routeName),
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
    final theme = Theme.of(context);

    // Determine device status color
    Color statusColor;
    switch (device.status) {
      case DeviceStatus.online:
        statusColor = Colors.green;
        break;
      case DeviceStatus.warning:
        statusColor = Colors.orange;
        break;
      case DeviceStatus.error:
        statusColor = Colors.red;
        break;
      case DeviceStatus.offline:
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.blue;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status indicator and MAC address
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      device.macAddress,
                      style: theme.textTheme.subtitle1?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              
              // Device info
              Text(
                'IP: ${device.ipv4.isNotEmpty ? device.ipv4 : "Unknown"}',
                style: theme.textTheme.bodyText2,
              ),
              SizedBox(height: 4),
              Text(
                'Cameras: ${device.cameras.length}',
                style: theme.textTheme.bodyText2,
              ),
              SizedBox(height: 4),
              Text(
                'Status: ${device.status.toString().split('.').last}',
                style: theme.textTheme.bodyText2,
              ),
              
              Spacer(),
              
              // View button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.videocam),
                    label: Text('View Cameras'),
                    onPressed: onTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
