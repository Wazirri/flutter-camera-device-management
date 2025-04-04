import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../providers/camera_devices_provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';

class CameraDevicesScreen extends StatefulWidget {
  const CameraDevicesScreen({Key? key}) : super(key: key);

  @override
  _CameraDevicesScreenState createState() => _CameraDevicesScreenState();
}

class _CameraDevicesScreenState extends State<CameraDevicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CameraDevice? _selectedDevice;
  String searchQuery = '';
  bool showOnlyActive = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  void _selectDevice(CameraDevice device) {
    setState(() {
      _selectedDevice = device;
    });
    
    // Select in provider
    final provider = Provider.of<CameraDevicesProvider>(context, listen: false);
    provider.setSelectedDevice(device.macKey);
  }
  
  void _updateSearchQuery(String query) {
    setState(() {
      searchQuery = query;
    });
  }
  
  void _toggleActiveFilter() {
    setState(() {
      showOnlyActive = !showOnlyActive;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Devices'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Devices'),
            Tab(text: 'Cameras'),
          ],
        ),
        actions: [
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Devices',
            onPressed: () {
              showSearch(
                context: context,
                delegate: DeviceSearchDelegate(
                  onDeviceSelected: _selectDevice,
                ),
              );
            },
          ),
          
          // Filter toggle
          IconButton(
            icon: Icon(
              showOnlyActive 
                ? Icons.filter_alt
                : Icons.filter_alt_outlined,
            ),
            tooltip: 'Filter Active Devices',
            onPressed: _toggleActiveFilter,
          ),
        ],
      ),
      body: Consumer<CameraDevicesProvider>(
        builder: (context, provider, child) {
          // If loading, show a spinner
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          // If there are no devices, show empty state
          if (provider.devicesList.isEmpty) {
            return _buildEmptyState(provider);
          }
          
          // Filter devices based on connectivity status if needed
          var displayDevices = provider.devicesList;
          if (showOnlyActive) {
            displayDevices = displayDevices.where((device) => device.connected).toList();
          }
          
          return TabBarView(
            controller: _tabController,
            children: [
              // Devices tab
              _buildDevicesTab(displayDevices, provider),
              
              // Cameras tab (redirects to CamerasScreen)
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CamerasScreen(),
                ),
              );
              // For now, just show a redirection message
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.videocam,
                      size: 64,
                      color: AppTheme.primaryBlue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera View',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use the Cameras screen to manage individual cameras',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/cameras');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                      ),
                      child: const Text('Go to Cameras'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Refresh devices
          final provider = Provider.of<CameraDevicesProvider>(context, listen: false);
          provider.refreshCameras();
        },
        backgroundColor: AppTheme.primaryOrange,
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  Widget _buildDevicesTab(List<CameraDevice> devices, CameraDevicesProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        final isSelected = _selectedDevice?.macKey == device.macKey;
        
        return Card(
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: AppTheme.primaryOrange, width: 2)
                : BorderSide.none,
          ),
          margin: const EdgeInsets.only(bottom: 16.0),
          child: InkWell(
            onTap: () => _selectDevice(device),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device header with status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.devices,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Device ${device.macAddress.substring(0, 8)}...',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  device.connected ? Icons.link : Icons.link_off,
                                  size: 14,
                                  color: device.connected ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  device.connected ? 'Connected' : 'Disconnected',
                                  style: TextStyle(
                                    color: device.connected ? Colors.green : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Last seen: ${device.lastSeenAt}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Camera count badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${device.cameras.length} ${device.cameras.length == 1 ? 'Camera' : 'Cameras'}',
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Device details
                  _buildInfoRow('IP Address', device.ipv4),
                  _buildInfoRow('MAC Address', device.macAddress),
                  if (device.firmwareVersion.isNotEmpty)
                    _buildInfoRow('Firmware', device.firmwareVersion),
                  if (device.deviceType.isNotEmpty)
                    _buildInfoRow('Device Type', device.deviceType),
                  if (device.uptime.isNotEmpty)
                    _buildInfoRow('Uptime', device.uptime),
                  
                  const SizedBox(height: 16),
                  
                  // Camera previews
                  if (device.cameras.isNotEmpty) ...[
                    const Text(
                      'Cameras',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: device.cameras.length,
                        itemBuilder: (context, index) {
                          final camera = device.cameras[index];
                          return _buildCameraPreview(camera);
                        },
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                        onPressed: () {
                          provider.updateDeviceConnectionStatus(
                            device.macAddress,
                            !device.connected, // Toggle for demo
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.videocam),
                        label: const Text('View Cameras'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                        ),
                        onPressed: () {
                          _selectDevice(device);
                          _tabController.animateTo(1); // Switch to cameras tab
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCameraPreview(Camera camera) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: camera.connected ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera snapshot or placeholder
          camera.mainSnapShot.isNotEmpty
              ? Image.network(
                  camera.mainSnapShot,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                    );
                  },
                )
              : const Icon(
                  Icons.videocam_off,
                  color: Colors.white54,
                ),
                
          // Status indicator
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                camera.name.isEmpty ? 'Cam ${camera.index}' : camera.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Connected indicator
          if (camera.connected)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.videocam,
                  color: Colors.green,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(CameraDevicesProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.devices_other,
            size: 72,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Devices Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect to your network to discover devices',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Devices'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            onPressed: () {
              provider.refreshCameras();
            },
          ),
        ],
      ),
    );
  }
}

class DeviceSearchDelegate extends SearchDelegate<CameraDevice?> {
  final Function(CameraDevice) onDeviceSelected;
  
  DeviceSearchDelegate({required this.onDeviceSelected});
  
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }
  
  Widget _buildSearchResults(BuildContext context) {
    final provider = Provider.of<CameraDevicesProvider>(context);
    final allDevices = provider.devicesList;
    
    if (query.isEmpty) {
      return const Center(
        child: Text('Type to search for devices'),
      );
    }
    
    final filteredDevices = allDevices.where((device) {
      return device.macAddress.toLowerCase().contains(query.toLowerCase()) ||
             device.ipv4.toLowerCase().contains(query.toLowerCase());
    }).toList();
    
    if (filteredDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No devices found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: filteredDevices.length,
      itemBuilder: (context, index) {
        final device = filteredDevices[index];
        
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.devices,
              color: AppTheme.primaryBlue,
            ),
          ),
          title: Text('Device ${device.macAddress.substring(0, 8)}...'),
          subtitle: Text(device.ipv4),
          trailing: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${device.cameras.length} ${device.cameras.length == 1 ? 'Camera' : 'Cameras'}',
              style: const TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: () {
            onDeviceSelected(device);
            close(context, device);
          },
        );
      },
    );
  }
}

// Stub of the CamerasScreen to prevent errors
class CamerasScreen extends StatelessWidget {
  const CamerasScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cameras')),
      body: const Center(child: Text('Cameras Screen')),
    );
  }
}
