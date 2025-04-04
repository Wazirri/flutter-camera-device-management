import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_devices_provider.dart';
import '../providers/websocket_provider.dart';
import '../widgets/camera_grid_item.dart';
import '../widgets/desktop_side_menu.dart';
import '../widgets/mobile_bottom_navigation_bar.dart';
import '../utils/platform_utils.dart';
import '../utils/page_transitions.dart';
import '../theme/app_theme.dart';

class CamerasScreen extends StatefulWidget {
  static const String routeName = '/cameras';

  const CamerasScreen({Key? key}) : super(key: key);

  @override
  _CamerasScreenState createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  String _selectedDeviceId = '';
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    // Request camera information when screen is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCamerasList();
    });
  }
  
  // Refresh camera list
  Future<void> _refreshCamerasList() async {
    setState(() {
      _isLoading = true;
    });
    
    // Request camera information from server
    final websocketProvider = Provider.of<WebSocketProvider>(context, listen: false);
    if (websocketProvider.isConnected) {
      websocketProvider.service.requestCameraInfo();
      print('🔄 [CamerasScreen] Requested fresh camera data from server');
    } else {
      print('⚠️ [CamerasScreen] Cannot refresh cameras - WebSocket not connected');
    }
    
    // Wait a moment for the data to load
    await Future.delayed(Duration(seconds: 1));
    
    // Get the list of cameras and select the first device if none selected
    final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    final devices = cameraProvider.devices;
    
    // Select the first device if none is selected
    if (_selectedDeviceId.isEmpty && devices.isNotEmpty) {
      setState(() {
        _selectedDeviceId = devices.keys.first;
      });
    }
    
    // Print device report to debug console
    cameraProvider.debugPrintDevices();
    
    setState(() {
      _isLoading = false;
    });
  }
  
  // Handle device selection change
  void _onDeviceChanged(String deviceId) {
    setState(() {
      _selectedDeviceId = deviceId;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final cameraProvider = Provider.of<CameraDevicesProvider>(context);
    final isDesktop = PlatformUtils.isDesktop();
    
    // Get the list of cameras for the selected device
    List<Widget> cameraTiles = [];
    if (_selectedDeviceId.isNotEmpty) {
      final selectedDevice = cameraProvider.devices[_selectedDeviceId];
      if (selectedDevice != null) {
        cameraTiles = selectedDevice.cameras.map((camera) {
          return CameraGridItem(
            camera: camera,
            deviceId: _selectedDeviceId,
            cameraIndex: camera.index,
          );
        }).toList();
      }
    }
    
    // Build the side panel to select devices
    Widget buildSidePanel() {
      // Get all devices and sort them alphabetically
      final devices = cameraProvider.devicesList;
      devices.sort((a, b) => a.macAddress.compareTo(b.macAddress));
      
      return Container(
        width: 220,
        color: AppTheme.panelBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Camera Devices',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
            ),
            Divider(color: Colors.white24),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshCamerasList,
                child: devices.isEmpty
                    ? Center(
                        child: Text(
                          'No devices found',
                          style: TextStyle(color: Colors.white60),
                        ),
                      )
                    : ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          bool isSelected = device.macKey == _selectedDeviceId;
                          
                          // Build a list of all camera names for this device
                          List<Widget> cameraNames = device.cameras.map((camera) {
                            return Padding(
                              padding: EdgeInsets.only(left: 24.0, top: 4.0, bottom: 4.0),
                              child: Text(
                                camera.name,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList();
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(
                                  'Device ${index + 1}',
                                  style: TextStyle(
                                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  '${device.macAddress}\n${device.cameras.length} cameras',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                                selected: isSelected,
                                tileColor: isSelected ? Colors.white.withOpacity(0.1) : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                onTap: () {
                                  _onDeviceChanged(device.macKey);
                                },
                              ),
                              // Only show camera names if this device is selected
                              if (isSelected) ...cameraNames,
                            ],
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Build the main content area with camera grid
    Widget buildCamerasGrid() {
      return RefreshIndicator(
        onRefresh: _refreshCamerasList,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : cameraTiles.isEmpty
                ? Center(
                    child: Text(
                      'No cameras found for the selected device',
                      style: TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isDesktop ? 3 : 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: cameraTiles.length,
                    itemBuilder: (context, index) {
                      return cameraTiles[index];
                    },
                  ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Cameras'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshCamerasList,
            tooltip: 'Refresh Cameras',
          ),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                if (isDesktop) DesktopSideMenu(currentRoute: CamerasScreen.routeName),
                buildSidePanel(),
                Expanded(child: buildCamerasGrid()),
              ],
            )
          : buildCamerasGrid(),
      bottomNavigationBar: isDesktop
          ? null
          : MobileBottomNavigationBar(currentRoute: CamerasScreen.routeName),
    );
  }
}
