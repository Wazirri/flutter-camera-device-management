import 'package:flutter/material.dart';
import '../models/camera_device.dart';
import '../widgets/camera_grid_item.dart';
import '../providers/camera_devices_provider_optimized.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'live_view_screen.dart';
import 'record_view_screen.dart';
import "../widgets/camera_details_bottom_sheet.dart";

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({Key? key}) : super(key: key);

  @override
  _CamerasScreenState createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  Camera? selectedCamera;
  String searchQuery = '';
  bool showOnlyActive = false;
  bool isGridView = false; // Default to list view
  String? selectedMacAddress;

  @override
  void initState() {
    super.initState();
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
        builder: (context) => RecordViewScreen(camera: camera),
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
          if (!isGridView)
            IconButton(
              icon: const Icon(Icons.view_list),
              tooltip: 'Default to List View',
              onPressed: () {
                setState(() {
                  isGridView = false;
                });
              },
            ),
        ],
      ),
      body: Consumer<CameraDevicesProviderOptimized>(
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
                      provider.refreshCameras();
                    },
                  ),
                ],
              ),
            );
          }
          
          // Group cameras by MAC address
          final groupedCameras = provider.getCamerasByMacAddress();
          
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
                  ...groupedCameras.keys.map((macAddress) {
                    final deviceCount = groupedCameras[macAddress]?.length ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text('Device ${macAddress.substring(0, 8)}... ($deviceCount)'),
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
          List<Camera> displayCameras = [];
          
          if (selectedMacAddress != null) {
            // Filter by selected MAC address
            displayCameras = groupedCameras[selectedMacAddress] ?? [];
          } else {
            // Show all cameras
            displayCameras = provider.cameras;
          }
          
          // Apply active filter if needed
          if (showOnlyActive) {
            displayCameras = displayCameras.where((camera) => camera.connected).toList();
          }
          
          // Content section with filtered cameras
          final cameraContent = Expanded(
            child: isGridView
                ? GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: displayCameras.length,
                    itemBuilder: (context, index) {
                      final camera = displayCameras[index];
                      
                      return CameraGridItem(
                        camera: camera,
                        index: index,
                        isSelected: selectedCamera?.id == camera.id,
                        onTap: () => _selectCamera(camera),
                        onLiveView: () => _openLiveView(camera),
                        onPlayback: () => _openRecordView(camera),
                      );
                    },
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: displayCameras.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final camera = displayCameras[index];
                      
                      // List item
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        elevation: 2,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _selectCamera(camera),
                          child: Row(
                            children: [
                              // Camera preview/thumbnail
                              SizedBox(
                                width: 120,
                                height: 80,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Camera image
                                    Container(
                                      color: Colors.black,
                                      child: camera.mainSnapShot.isNotEmpty
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
                                    
                                    // Status indicator
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
                              
                              // Camera details
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        camera.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16.0,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            camera.connected ? Icons.link : Icons.link_off,
                                            size: 14.0,
                                            color: camera.connected
                                              ? Colors.green
                                              : Colors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            camera.connected ? 'Connected' : 'Disconnected',
                                            style: TextStyle(
                                              fontSize: 12.0,
                                              color: camera.connected
                                                ? Colors.green
                                                : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        camera.ip,
                                        style: TextStyle(
                                          fontSize: 12.0,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Actions
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.videocam),
                                    onPressed: () => _openLiveView(camera),
                                    tooltip: 'Live View',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.video_library),
                                    onPressed: () => _openRecordView(camera),
                                    tooltip: 'Recordings',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
          
          // Combine filters with content
          return Column(
            children: [
              macAddressFilters,
              cameraContent,
            ],
          );
        },
      ),
    );
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
