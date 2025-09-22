import 'package:flutter/material.dart';
import '../models/camera_device.dart';
import '../widgets/camera_grid_item.dart';
import '../providers/camera_devices_provider_optimized.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'live_view_screen.dart';
import 'multi_recordings_screen.dart';

import "../widgets/camera_details_bottom_sheet.dart";

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({Key? key}) : super(key: key);

  @override
  _CamerasScreenState createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> with SingleTickerProviderStateMixin {
  Camera? selectedCamera;
  String searchQuery = '';
  bool showOnlyActive = false;
  bool isGridView = false; // Default to list view
  String? selectedMacAddress;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Check if there's a selected device and auto-filter cameras for that device
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
      final selectedDevice = provider.selectedDevice;
      if (selectedDevice != null) {
        setState(() {
          selectedMacAddress = selectedDevice.macKey;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper method to check if camera has a real MAC address (not a temp placeholder ID)
  bool _hasMacAddress(Camera camera) {
    // MAC adresi gerçek MAC format'ında mı kontrol et (örn: me8_b7_23_0c_12_43)
    // Geçici ID'ler genelde "deviceKey_cam_index" formatında
    return camera.mac.isNotEmpty && 
           !camera.mac.contains('_cam_') && 
           !camera.mac.contains('_placeholder_');
  }
  
  void _selectCamera(Camera camera) {
    setState(() {
      selectedCamera = camera;
    });
    
    // Kamera detaylarını BottomSheet olarak göster
    _showCameraDetails(camera);
  }
  
  void _showCameraDetails(Camera camera) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return CameraDetailsBottomSheet(
              camera: camera,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
  
  void _openLiveView(Camera camera) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => LiveViewScreen(camera: camera),
      ),
    );
  }
  
  void _openRecordView(Camera camera) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => const MultiRecordingsScreen(),
      ),
    );
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
  
  void _toggleViewMode() {
    setState(() {
      isGridView = !isGridView;
    });
  }
  
  void _selectMacAddress(String? macAddress) {
    setState(() {
      if (selectedMacAddress == macAddress) {
        // Tapping the same filter toggles it off
        selectedMacAddress = null;
      } else {
        selectedMacAddress = macAddress;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cameras'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.devices),
              text: 'By Device',
            ),
            Tab(
              icon: Icon(Icons.group_work),
              text: 'By Group',
            ),
          ],
        ),
        actions: [
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Cameras',
            onPressed: () {
              showSearch(
                context: context,
                delegate: CameraSearchDelegate(
                  onCameraSelected: (camera) {
                    _selectCamera(camera);
                    // Optionally navigate to camera details
                  },
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
            tooltip: 'Filter Active Cameras',
            onPressed: _toggleActiveFilter,
          ),
          
          // View mode toggle
          IconButton(
            icon: Icon(
              isGridView 
                ? Icons.grid_view 
                : Icons.list,
            ),
            tooltip: isGridView 
              ? 'Switch to List View' 
              : 'Switch to Grid View',
            onPressed: _toggleViewMode,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDeviceGroupedView(),
          _buildCameraGroupedView(),
        ],
      ),
    );
  }

  Widget _buildDeviceGroupedView() {
    return Consumer<CameraDevicesProviderOptimized>(
      builder: (context, provider, child) {
        // If loading, show a spinner
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        // If there are no cameras, show empty state
        if (provider.cameras.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off_outlined,
                  size: 64.0,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16.0),
                const Text(
                  'No cameras found',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Connect to your network to discover cameras',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24.0),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  onPressed: () {
                    // provider.refreshCameras(); // Method removed, WebSocket handles updates
                  },
                ),
              ],
            ),
          );
        }
        
        // Group cameras by device MAC address - use devicesList
        final groupedCamerasByMac = <String, List<Camera>>{};
        for (var device in provider.devicesList) {
          groupedCamerasByMac[device.macKey] = device.cameras;
        }
        
        // Build the MAC address filter chips
        final macAddressFilters = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "All" filter chip
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: const Text('All Devices'),
                    selected: selectedMacAddress == null,
                    onSelected: (_) => _selectMacAddress(null),
                    backgroundColor: Theme.of(context).cardColor,
                    selectedColor: AppTheme.primaryOrange.withOpacity(0.2),
                  ),
                ),
                
                // MAC address filter chips
                ...groupedCamerasByMac.keys.map((macAddress) {
                  final deviceCount = groupedCamerasByMac[macAddress]?.length ?? 0;
                  final deviceName = _getDeviceName(context, macAddress);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text('$deviceName ($deviceCount)'),
                      selected: selectedMacAddress == macAddress,
                      onSelected: (_) => _selectMacAddress(macAddress),
                      backgroundColor: Theme.of(context).cardColor,
                      selectedColor: AppTheme.primaryOrange.withOpacity(0.2),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
        
        // Filter cameras based on selected MAC address and active status
        List<Camera> baseFilteredCameras = [];
        
        if (selectedMacAddress != null) {
          // Filter by selected MAC address
          baseFilteredCameras = groupedCamerasByMac[selectedMacAddress] ?? [];
        } else {
          // Show all cameras from all devices
          baseFilteredCameras = [];
          for (var device in provider.devicesList) {
            baseFilteredCameras.addAll(device.cameras);
          }
        }
        
        // Apply active filter if needed
        if (showOnlyActive) {
          baseFilteredCameras = baseFilteredCameras.where((camera) => camera.connected).toList();
        }

        // Group the filtered cameras by their actual device assignment
        final Map<String, List<Camera>> camerasGroupedByDevice = {};
        for (var camera in baseFilteredCameras) {
          // Find which device this camera belongs to by checking devicesList
          String? deviceMac;
          String? deviceName;
          
          for (var device in provider.devicesList) {
            if (device.cameras.any((c) => c.id == camera.id)) {
              deviceMac = device.macKey;
              deviceName = _getDeviceName(context, deviceMac);
              print('DEBUG: Camera ${camera.name} (${camera.id}) found in device $deviceName ($deviceMac)');
              break;
            }
          }
          
          // Use device name if found, otherwise try to get from camera's currentDevice
          if (deviceName == null && camera.currentDevice != null) {
            deviceMac = camera.currentDevice!.deviceMac;
            deviceName = _getDeviceName(context, deviceMac);
            print('DEBUG: Camera ${camera.name} (${camera.id}) using currentDevice $deviceName ($deviceMac)');
          }
          
          if (deviceName == null) {
            print('DEBUG: Camera ${camera.name} (${camera.id}) has no device assignment - adding to Ungrouped');
          }
          
          final groupName = deviceName ?? 'Ungrouped Cameras';
          camerasGroupedByDevice.putIfAbsent(groupName, () => []).add(camera);
        }

        return _buildGroupedCameraContent(camerasGroupedByDevice, macAddressFilters);
      },
    );
  }

  Widget _buildCameraGroupedView() {
    return Consumer<CameraDevicesProviderOptimized>(
      builder: (context, provider, child) {
        // If loading, show a spinner
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        // If there are no cameras, show empty state
        if (provider.cameras.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off_outlined,
                  size: 64.0,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16.0),
                const Text(
                  'No cameras found',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Connect to your network to discover cameras',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24.0),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  onPressed: () {
                    // provider.refreshCameras(); // Method removed, WebSocket handles updates
                  },
                ),
              ],
            ),
          );
        }

        // Get camera groups using the same method as CameraGroupsScreen
        final cameraGroups = provider.cameraGroupsList;
        
        // Group cameras by their camera groups
        final Map<String, List<Camera>> camerasGroupedByName = {};
        
        // Get all cameras
        List<Camera> allCameras = showOnlyActive 
          ? provider.cameras.where((camera) => camera.connected).toList()
          : provider.cameras;
        
        // Track which cameras are assigned to groups
        Set<String> assignedCameraIds = {};
        
        if (cameraGroups.isNotEmpty) {
          // Initialize groups
          for (final group in cameraGroups) {
            camerasGroupedByName[group.name] = [];
          }
          
          // Get cameras for each group using the provider method
          for (final group in cameraGroups) {
            final camerasInGroup = provider.getCamerasInGroup(group.name);
            // Apply active filter if needed
            List<Camera> filteredCameras = showOnlyActive 
              ? camerasInGroup.where((camera) => camera.connected).toList()
              : camerasInGroup;
            camerasGroupedByName[group.name] = filteredCameras;
            
            // Track assigned cameras
            for (final camera in filteredCameras) {
              assignedCameraIds.add(camera.id);
            }
          }
        }
        
        // Find ungrouped cameras (not assigned to any group)
        final ungroupedCameras = allCameras.where((camera) => !assignedCameraIds.contains(camera.id)).toList();
        
        // Add ungrouped cameras to a separate group if any exist
        if (ungroupedCameras.isNotEmpty) {
          camerasGroupedByName['Ungrouped Cameras'] = ungroupedCameras;
        }

        // Remove empty groups
        camerasGroupedByName.removeWhere((key, value) => value.isEmpty);

        return _buildGroupedCameraContent(camerasGroupedByName, null);
      },
    );
  }

  Widget _buildGroupedCameraContent(Map<String, List<Camera>> groupedCameras, Widget? filterChips) {
    final sortedGroupNames = groupedCameras.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    final cameraContent = Expanded(
      child: CustomScrollView(
        slivers: sortedGroupNames.expand<Widget>((groupName) {
          final camerasInGroup = groupedCameras[groupName]!;
          if (camerasInGroup.isEmpty) {
            return <Widget>[];
          }

          final List<Widget> groupWidgets = [];

          groupWidgets.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );

          if (isGridView) {
            groupWidgets.add(
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: camerasInGroup.length,
                  itemBuilder: (context, index) {
                    final camera = camerasInGroup[index];
                    return CameraGridItem(
                      camera: camera,
                      index: index,
                      isSelected: selectedCamera?.id == camera.id,
                      onTap: () => _selectCamera(camera),
                      onLiveView: () => _openLiveView(camera),
                      onPlayback: () => _openRecordView(camera),
                    );
                  },
                ),
              ),
            );
          } else {
            groupWidgets.add(
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final camera = camerasInGroup[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        elevation: 2,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _selectCamera(camera),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 120,
                                height: 80,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(
                                      color: !_hasMacAddress(camera) ? Colors.grey[800] : Colors.black,
                                      child: !_hasMacAddress(camera)
                                          ? const Icon(
                                              Icons.videocam_off_outlined,
                                              size: 36.0,
                                              color: Colors.grey,
                                            )
                                          : camera.mainSnapShot.isNotEmpty
                                              ? Image.network(
                                                  camera.mainSnapShot,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return const Icon(
                                                      Icons.broken_image_outlined,
                                                      size: 36.0,
                                                      color: Colors.white54,
                                                    );
                                                  },
                                                )
                                              : const Icon(
                                                  Icons.videocam_off,
                                                  size: 36.0,
                                                  color: Colors.white54,
                                                ),
                                    ),
                                    if (camera.connected)
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6.0,
                                            vertical: 2.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.fiber_manual_record,
                                                color: Colors.red,
                                                size: 10,
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                'LIVE',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              camera.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16.0,
                                                color: !_hasMacAddress(camera) ? Colors.grey : null,
                                              ),
                                            ),
                                          ),
                                          if (!_hasMacAddress(camera))
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.orange, width: 1),
                                              ),
                                              child: const Text(
                                                'NO MAC',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            camera.connected ? Icons.link : Icons.link_off,
                                            size: 14.0,
                                            color: camera.connected ? Colors.green : Colors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            camera.connected ? 'Connected' : 'Disconnected',
                                            style: TextStyle(
                                              fontSize: 12.0,
                                              color: camera.connected ? Colors.green : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // IP Address
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.language,
                                            size: 12.0,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            camera.ip,
                                            style: TextStyle(
                                              fontSize: 12.0,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Current device assignment
                                      if (camera.currentDevice != null)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.device_hub,
                                              size: 12.0,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                _getDeviceName(context, camera.currentDevice!.deviceMac),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12.0,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (camera.currentDevice != null) const SizedBox(height: 4),
                                      // Resolution and additional info row
                                      Row(
                                        children: [
                                          // Resolution
                                          if (camera.recordWidth > 0 && camera.recordHeight > 0) ...[
                                            Icon(
                                              Icons.high_quality,
                                              size: 12.0,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${camera.recordWidth}x${camera.recordHeight}',
                                              style: const TextStyle(
                                                fontSize: 11.0,
                                                color: Colors.orange,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                          // History count
                                          if (camera.deviceHistory.isNotEmpty) ...[
                                            Icon(
                                              Icons.history,
                                              size: 12.0,
                                              color: Colors.purple,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${camera.deviceHistory.length}',
                                              style: const TextStyle(
                                                fontSize: 11.0,
                                                color: Colors.purple,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                          // Recording status
                                          if (camera.recording) ...[
                                            Icon(
                                              Icons.fiber_manual_record,
                                              size: 12.0,
                                              color: Colors.red,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'REC',
                                              style: const TextStyle(
                                                fontSize: 11.0,
                                                color: Colors.red,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.videocam,
                                      color: !_hasMacAddress(camera) ? Colors.grey : null,
                                    ),
                                    onPressed: !_hasMacAddress(camera) ? null : () => _openLiveView(camera),
                                    tooltip: !_hasMacAddress(camera) ? 'No MAC Address' : 'Live View',
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.video_library,
                                      color: !_hasMacAddress(camera) ? Colors.grey : null,
                                    ),
                                    onPressed: !_hasMacAddress(camera) ? null : () => _openRecordView(camera),
                                    tooltip: !_hasMacAddress(camera) ? 'No MAC Address' : 'Recordings',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: camerasInGroup.length,
                ),
              ),
            );

            groupWidgets.add(
              const SliverToBoxAdapter(
                child: Divider(height: 1, indent: 16, endIndent: 16),
              ),
            );
          }

          return groupWidgets;
        }).toList(),
      ),
    );

    return Column(
      children: [
        if (filterChips != null) filterChips,
        cameraContent,
      ],
    );
  }

  // Get device name and IP from MAC address
  String _getDeviceName(BuildContext context, String deviceMac) {
    try {
      final provider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
      
      // Convert device MAC to the format used in devices map (from m_XX_XX_XX_XX_XX_XX to XX:XX:XX:XX:XX:XX)
      String normalizedMac = deviceMac;
      if (deviceMac.startsWith('m_')) {
        normalizedMac = deviceMac.substring(2).replaceAll('_', ':');
      }
      
      // Find device by MAC address
      for (var device in provider.devices.values) {
        if (device.macAddress == normalizedMac || device.macKey == deviceMac) {
          String deviceName = '';
          if (device.deviceName?.isNotEmpty == true) {
            deviceName = device.deviceName!;
          } else if (device.deviceType.isNotEmpty) {
            deviceName = device.deviceType;
          } else {
            // Use shortened MAC as fallback for readability
            String shortMac;
            if (deviceMac.startsWith('m_')) {
              // For MAC format like mf8_ce_07_f2_8c_b6, extract meaningful part
              final macPart = deviceMac.substring(1); // remove 'm'
              final parts = macPart.split('_');
              if (parts.length >= 3) {
                // Take first 3 parts: f8_ce_07
                shortMac = '${parts[0]}_${parts[1]}_${parts[2]}';
              } else {
                shortMac = macPart;
              }
            } else {
              shortMac = deviceMac;
            }
            deviceName = shortMac;
          }
          
          // Add IP address if available
          if (device.ipv4.isNotEmpty) {
            deviceName += ' (${device.ipv4})';
          }
          
          print('DEBUG: Device $deviceMac using full name "$deviceName"');
          return deviceName;
        }
      }
      
      // If not found, return shortened MAC with better formatting
      String shortMac;
      if (deviceMac.startsWith('m_')) {
        // For MAC format like mf8_ce_07_f2_8c_b6, extract meaningful part
        final macPart = deviceMac.substring(1); // remove 'm'
        final parts = macPart.split('_');
        if (parts.length >= 3) {
          // Take first 3 parts: f8_ce_07
          shortMac = '${parts[0]}_${parts[1]}_${parts[2]}';
        } else {
          shortMac = macPart;
        }
      } else {
        shortMac = deviceMac;
      }
      print('DEBUG: Device $deviceMac not found, using MAC "$shortMac"');
      return shortMac;
    } catch (e) {
      String shortMac;
      if (deviceMac.startsWith('m_')) {
        // For MAC format like mf8_ce_07_f2_8c_b6, extract meaningful part
        final macPart = deviceMac.substring(1); // remove 'm'
        final parts = macPart.split('_');
        if (parts.length >= 3) {
          // Take first 3 parts: f8_ce_07
          shortMac = '${parts[0]}_${parts[1]}_${parts[2]}';
        } else {
          shortMac = macPart;
        }
      } else {
        shortMac = deviceMac;
      }
      print('DEBUG: Error for device $deviceMac, using fallback "$shortMac"');
      return shortMac;
    }
  }
}

// Camera Search Delegate for searching cameras
class CameraSearchDelegate extends SearchDelegate<Camera> {
  final Function(Camera) onCameraSelected;

  CameraSearchDelegate({required this.onCameraSelected});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, Camera(
          index: -1,
          name: '',
          ip: '',
          username: '',
          password: '',
          brand: '',
          mediaUri: '',
          recordUri: '',
          subUri: '',
          remoteUri: '',
          mainSnapShot: '',
          subSnapShot: '',
          recordWidth: 0,
          recordHeight: 0,
          subWidth: 0,
          subHeight: 0,
          connected: false,
          lastSeenAt: '',
          recording: false,
        ));
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
    final provider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    final cameras = provider.cameras;

    if (query.isEmpty) {
      return const Center(
        child: Text('Type to search cameras...'),
      );
    }

    final lowercaseQuery = query.toLowerCase();
    final filteredCameras = cameras.where((camera) {
      return camera.name.toLowerCase().contains(lowercaseQuery) ||
          camera.ip.toLowerCase().contains(lowercaseQuery) ||
          camera.brand.toLowerCase().contains(lowercaseQuery);
    }).toList();

    if (filteredCameras.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "$query"',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredCameras.length,
      itemBuilder: (context, index) {
        final camera = filteredCameras[index];

        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
            ),
            child: camera.mainSnapShot.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      camera.mainSnapShot,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image_outlined,
                          size: 24.0,
                          color: Colors.white54,
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.videocam_off,
                    size: 24.0,
                    color: Colors.white54,
                  ),
          ),
          title: Text(camera.name),
          subtitle: Text(camera.ip),
          trailing: Icon(
            camera.connected ? Icons.link : Icons.link_off,
            color: camera.connected ? Colors.green : Colors.red,
          ),
          onTap: () {
            onCameraSelected(camera);
            close(context, camera);
          },
        );
      },
    );
  }
}
