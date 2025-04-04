import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/camera_grid_item.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/status_indicator.dart';
import '../models/camera_device.dart';
import '../providers/camera_devices_provider.dart';

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({Key? key}) : super(key: key);

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Online', 'Offline', 'Issues'];
  final List<String> _sortOptions = ['Name', 'Status', 'Last Active', 'Model'];
  String _selectedSort = 'Name';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: CustomAppBar(
        title: 'Cameras',
        isDesktop: isDesktop,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: _buildCameraGrid(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search cameras',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.darkSurface,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (value) {
          // Trigger search as user types
          setState(() {});
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', _selectedFilter == 'All'),
          _buildFilterChip('Online', _selectedFilter == 'Online',
              leadingIcon: StatusIndicator(
                status: DeviceStatus.online,
                size: 10,
                padding: EdgeInsets.zero,
              )),
          _buildFilterChip('Offline', _selectedFilter == 'Offline',
              leadingIcon: StatusIndicator(
                status: DeviceStatus.offline,
                size: 10,
                padding: EdgeInsets.zero,
              )),
          _buildFilterChip('Issues', _selectedFilter == 'Issues',
              leadingIcon: StatusIndicator(
                status: DeviceStatus.warning,
                size: 10,
                padding: EdgeInsets.zero,
              )),
          _buildFilterChip('Recording', _selectedFilter == 'Recording',
              leadingIcon: const Icon(
                Icons.fiber_manual_record,
                size: 14,
                color: Colors.red,
              )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, {Widget? leadingIcon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        avatar: leadingIcon,
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
        backgroundColor: AppTheme.darkSurface,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.darkTextPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (selected) {
          setState(() {
            _selectedFilter = label;
          });
        },
      ),
    );
  }

  Widget _buildCameraGrid(BuildContext context) {
    final crossAxisCount = ResponsiveHelper.getResponsiveGridCount(
      context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
    );

    return Consumer<CameraDevicesProvider>(
      builder: (context, provider, child) {
        // Get all cameras from all devices
        final allCameras = provider.allCameras;
        
        if (allCameras.isEmpty) {
          return const Center(
            child: Text(
              'No cameras found.\nConnect to the server to view cameras.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          );
        }
        
        // Filter cameras based on selected filter
        final filteredCameras = _filterCameras(allCameras);
        
        // Sort cameras based on selected sort option
        _sortCameras(filteredCameras);
        
        // Further filter by search text if any
        final searchText = _searchController.text.toLowerCase();
        final displayCameras = searchText.isEmpty 
            ? filteredCameras 
            : filteredCameras.where((camera) => 
                camera.name.toLowerCase().contains(searchText) ||
                camera.brand.toLowerCase().contains(searchText) ||
                camera.hw.toLowerCase().contains(searchText) ||
                camera.manufacturer.toLowerCase().contains(searchText)
              ).toList();
        
        if (displayCameras.isEmpty) {
          return Center(
            child: Text(
              searchText.isNotEmpty
                  ? 'No cameras matching "$searchText"'
                  : 'No cameras matching the selected filter',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          );
        }
        
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: displayCameras.length,
            itemBuilder: (context, index) {
              final camera = displayCameras[index];
              
              return CameraGridItem(
                name: camera.name,
                // Show manufacturer and model if available
                location: camera.manufacturer.isNotEmpty || camera.hw.isNotEmpty
                    ? '${camera.manufacturer} ${camera.hw}'
                    : 'Camera ${index + 1}',
                status: camera.status,
                isRecording: camera.recording,
                onTap: () {
                  // Find the device this camera belongs to
                  for (var device in provider.devicesList) {
                    int cameraIndex = device.cameras.indexWhere((c) => c.name == camera.name);
                    if (cameraIndex >= 0) {
                      provider.setSelectedDevice(device.macKey);
                      provider.setSelectedCameraIndex(cameraIndex);
                      Navigator.pushNamed(context, '/live-view');
                      break;
                    }
                  }
                },
                onSettingsTap: () {
                  _showCameraOptions(context, camera);
                },
              );
            },
          ),
        );
      },
    );
  }

  // Filter cameras based on the selected filter option
  List<Camera> _filterCameras(List<Camera> cameras) {
    switch (_selectedFilter) {
      case 'Online':
        return cameras.where((camera) => camera.connected).toList();
      case 'Offline':
        return cameras.where((camera) => !camera.connected).toList();
      case 'Issues':
        return cameras.where((camera) => 
            camera.status == DeviceStatus.warning || 
            camera.status == DeviceStatus.error).toList();
      case 'Recording':
        return cameras.where((camera) => camera.recording).toList();
      case 'All':
      default:
        return cameras;
    }
  }

  // Sort cameras based on the selected sort option
  void _sortCameras(List<Camera> cameras) {
    switch (_selectedSort) {
      case 'Name':
        cameras.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Status':
        cameras.sort((a, b) {
          if (a.connected && !b.connected) return -1;
          if (!a.connected && b.connected) return 1;
          return a.name.compareTo(b.name);
        });
        break;
      case 'Last Active':
        cameras.sort((a, b) {
          if (a.lastSeenAt.isEmpty) return 1;
          if (b.lastSeenAt.isEmpty) return -1;
          return b.lastSeenAt.compareTo(a.lastSeenAt);
        });
        break;
      case 'Model':
        cameras.sort((a, b) {
          if (a.hw.isEmpty) return 1;
          if (b.hw.isEmpty) return -1;
          int result = a.hw.compareTo(b.hw);
          return result == 0 ? a.name.compareTo(b.name) : result;
        });
        break;
    }
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: const Text(
                'Filter Cameras',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final option = _filterOptions[index];
                return ListTile(
                  leading: _getFilterIcon(option),
                  title: Text(option),
                  selected: _selectedFilter == option,
                  selectedTileColor: AppTheme.primaryBlue.withOpacity(0.15),
                  trailing: _selectedFilter == option
                      ? const Icon(Icons.check, color: AppTheme.primaryBlue)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedFilter = option;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _getFilterIcon(String filter) {
    switch (filter) {
      case 'All':
        return const Icon(Icons.all_inclusive);
      case 'Online':
        return StatusIndicator(
          status: DeviceStatus.online,
          size: 12,
          padding: EdgeInsets.zero,
        );
      case 'Offline':
        return StatusIndicator(
          status: DeviceStatus.offline,
          size: 12,
          padding: EdgeInsets.zero,
        );
      case 'Issues':
        return StatusIndicator(
          status: DeviceStatus.warning,
          size: 12,
          padding: EdgeInsets.zero,
        );
      case 'Recording':
        return const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12);
      default:
        return const Icon(Icons.filter_list);
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: const Text(
                'Sort Cameras',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _sortOptions.length,
              itemBuilder: (context, index) {
                final option = _sortOptions[index];
                return ListTile(
                  title: Text(option),
                  selected: _selectedSort == option,
                  selectedTileColor: AppTheme.primaryBlue.withOpacity(0.15),
                  trailing: _selectedSort == option
                      ? const Icon(Icons.check, color: AppTheme.primaryBlue)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedSort = option;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showCameraOptions(BuildContext context, Camera camera) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.black,
                    radius: 20,
                    child: Icon(
                      Icons.videocam,
                      color: AppTheme.primaryBlue,
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          camera.manufacturer.isNotEmpty || camera.hw.isNotEmpty
                              ? '${camera.manufacturer} ${camera.hw}'
                              : camera.brand,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkTextSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (camera.country.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Country: ${camera.country}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.darkTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Live'),
              onTap: () {
                Navigator.pop(context);
                
                // Find the device this camera belongs to
                final provider = Provider.of<CameraDevicesProvider>(context, listen: false);
                for (var device in provider.devicesList) {
                  int cameraIndex = device.cameras.indexWhere((c) => c.name == camera.name);
                  if (cameraIndex >= 0) {
                    provider.setSelectedDevice(device.macKey);
                    provider.setSelectedCameraIndex(cameraIndex);
                    Navigator.pushNamed(context, '/live-view');
                    break;
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('View Recordings'),
              onTap: () {
                Navigator.pop(context);
                
                // Find the device this camera belongs to
                final provider = Provider.of<CameraDevicesProvider>(context, listen: false);
                for (var device in provider.devicesList) {
                  int cameraIndex = device.cameras.indexWhere((c) => c.name == camera.name);
                  if (cameraIndex >= 0) {
                    provider.setSelectedDevice(device.macKey);
                    provider.setSelectedCameraIndex(cameraIndex);
                    Navigator.pushNamed(context, '/record-view');
                    break;
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Camera Details'),
              onTap: () {
                Navigator.pop(context);
                _showCameraDetails(context, camera);
              },
            ),
            ListTile(
              leading: Icon(
                camera.recording ? Icons.stop : Icons.fiber_manual_record,
                color: camera.recording ? Colors.grey : Colors.red,
              ),
              title: Text(camera.recording ? 'Stop Recording' : 'Start Recording'),
              onTap: () {
                Navigator.pop(context);
                // Toggle recording would go here in a real implementation
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
  
  void _showCameraDetails(BuildContext context, Camera camera) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(camera.name),
        backgroundColor: AppTheme.darkSurface,
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (camera.manufacturer.isNotEmpty)
                _detailRow('Manufacturer', camera.manufacturer),
              if (camera.hw.isNotEmpty)
                _detailRow('Model', camera.hw),
              if (camera.brand.isNotEmpty)
                _detailRow('Brand', camera.brand),
              if (camera.country.isNotEmpty)
                _detailRow('Country', camera.country),
              _detailRow('IP Address', camera.ip),
              _detailRow('Status', camera.connected ? 'Online' : 'Offline'),
              if (camera.recording)
                _detailRow('Recording', 'Yes', valueColor: Colors.red),
              const SizedBox(height: 8),
              const Divider(),
              const Text('Stream Properties', style: TextStyle(fontWeight: FontWeight.bold)),
              if (camera.recordWidth > 0 && camera.recordHeight > 0)
                _detailRow('Record Resolution', '${camera.recordWidth}x${camera.recordHeight}'),
              if (camera.recordCodec.isNotEmpty)
                _detailRow('Record Codec', camera.recordCodec),
              if (camera.subWidth > 0 && camera.subHeight > 0)
                _detailRow('Sub Resolution', '${camera.subWidth}x${camera.subHeight}'),
              if (camera.subCodec.isNotEmpty)
                _detailRow('Sub Codec', camera.subCodec),
              if (camera.mediaUri.isNotEmpty)
                _detailRow('Media URI', camera.mediaUri, small: true),
              if (camera.recordUri.isNotEmpty)
                _detailRow('Record URI', camera.recordUri, small: true),
              if (camera.subUri.isNotEmpty)
                _detailRow('Sub URI', camera.subUri, small: true),
              if (camera.remoteUri.isNotEmpty)
                _detailRow('Remote URI', camera.remoteUri, small: true),
              if (camera.xAddrs.isNotEmpty)
                _detailRow('ONVIF Address', camera.xAddrs, small: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Widget _detailRow(String label, String value, {bool small = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: small ? 12 : 14,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
