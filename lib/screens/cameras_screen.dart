import 'package:flutter/material.dart';
import '../models/camera_device.dart';
import '../widgets/camera_grid_item.dart';
import '../widgets/camera_snapshot_widget.dart';
import '../providers/camera_devices_provider.dart';
import '../providers/websocket_provider.dart';
import '../providers/user_group_provider.dart';
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

class _CamerasScreenState extends State<CamerasScreen>
    with SingleTickerProviderStateMixin {
  Camera? selectedCamera;
  String searchQuery = '';
  bool showOnlyActive = false;
  bool isGridView = false; // Default to list view
  String? selectedMacAddress;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // Grup genişletme durumları - varsayılan olarak tümü açık
  final Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Check if there's a selected device and auto-filter cameras for that device
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
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
    _searchController.dispose();
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

    // Doğrudan canlı izlemeye git
    _openLiveView(camera);
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

  bool _matchesSearch(Camera camera, String query) {
    if (query.isEmpty) return true;
    final lowercaseQuery = query.toLowerCase();
    return camera.name.toLowerCase().contains(lowercaseQuery) ||
        camera.displayName.toLowerCase().contains(lowercaseQuery) ||
        camera.ip.toLowerCase().contains(lowercaseQuery) ||
        camera.mac.toLowerCase().contains(lowercaseQuery);
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Kamera ara...',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade500, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.darkSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          isDense: true,
        ),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (value) => setState(() => searchQuery = value),
      ),
    );
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
          // Filter toggle
          IconButton(
            icon: Icon(
              showOnlyActive ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            tooltip: 'Filter Active Cameras',
            onPressed: _toggleActiveFilter,
          ),

          // View mode toggle
          IconButton(
            icon: Icon(
              isGridView ? Icons.grid_view : Icons.list,
            ),
            tooltip: isGridView ? 'Switch to List View' : 'Switch to Grid View',
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
    return Consumer3<CameraDevicesProviderOptimized, WebSocketProviderOptimized,
        UserGroupProvider>(
      builder: (context, provider, wsProvider, userGroupProvider, child) {
        // Get authorized camera MACs for current user
        final currentUsername = wsProvider.currentLoggedInUsername;
        Set<String>? authorizedMacs;

        print('[CameraScreen] 🔍 Current logged in username: $currentUsername');

        if (currentUsername != null) {
          // Check if user is admin
          final userType = userGroupProvider.getUserType(currentUsername);
          print('[CameraScreen] 👤 User type: $userType');

          if (userType == 'admin') {
            // Admin sees all cameras
            authorizedMacs = null;
            print('[CameraScreen] 👑 Admin user - showing all cameras');
          } else {
            // Regular user - get authorized cameras
            authorizedMacs =
                userGroupProvider.getUserAuthorizedCameraMacs(currentUsername);
            print(
                '[CameraScreen] 🔐 Regular user - authorized MACs: ${authorizedMacs.length} cameras');
            print('[CameraScreen] 📷 Authorized camera MACs: $authorizedMacs');
          }
        } else {
          print('[CameraScreen] ⚠️ No logged in user - showing all cameras');
        }

        // Get filtered cameras based on authorization
        final allCameras = provider.getAuthorizedCameras(authorizedMacs);
        
        // Apply search filter
        final filteredBySearch = searchQuery.isEmpty
            ? allCameras
            : allCameras.where((camera) => _matchesSearch(camera, searchQuery)).toList();
        
        print(
            '[CameraScreen] 📊 Total cameras available: ${provider.cameras.length}');
        print(
            '[CameraScreen] ✅ Filtered cameras to show: ${filteredBySearch.length}');

        // Build search bar widget
        final searchBar = _buildSearchBar();
        // If loading, show a spinner
        if (provider.isLoading) {
          return Column(
            children: [
              searchBar,
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          );
        }

        // If there are no cameras, show empty state
        if (filteredBySearch.isEmpty) {
          return Column(
            children: [
              searchBar,
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_outlined,
                        size: 64.0,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        searchQuery.isNotEmpty ? 'Sonuç bulunamadı' : 'No cameras found',
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 8.0),
                        Text(
                          '"$searchQuery" için eşleşme yok',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // Group ALL authorized cameras by their assigned device MAC address
        // This includes cameras from cameras_mac even if device is offline
        // A camera can be on MULTIPLE devices (currentDevices Map), so we add it to each device group
        final groupedCamerasByMac = <String, List<Camera>>{};
        for (var camera in filteredBySearch) {
          // Skip device MAC addresses (m_*) and cameras without MAC
          if (camera.mac.isEmpty || camera.mac.startsWith('m_')) continue;

          // Check if camera has currentDevices (can be on multiple devices)
          if (camera.currentDevices.isNotEmpty) {
            // Add camera to each device group it belongs to
            for (var deviceMac in camera.currentDevices.keys) {
              if (deviceMac.isNotEmpty) {
                groupedCamerasByMac
                    .putIfAbsent(deviceMac, () => [])
                    .add(camera);
              }
            }
          } else if (camera.parentDeviceMacKey != null &&
              camera.parentDeviceMacKey!.isNotEmpty) {
            // Fall back to parentDeviceMacKey if no currentDevices
            groupedCamerasByMac
                .putIfAbsent(camera.parentDeviceMacKey!, () => [])
                .add(camera);
          } else {
            // No device assignment - put in "Unassigned" group
            groupedCamerasByMac.putIfAbsent('Unassigned', () => []).add(camera);
          }
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

                // MAC address filter chips (sorted: device MACs first, then Unassigned)
                ...groupedCamerasByMac.keys
                    .where((key) => key != 'Unassigned') // Device MACs first
                    .map((macAddress) {
                  // Only count cameras with MAC address
                  final deviceCount = groupedCamerasByMac[macAddress]
                          ?.where((camera) => camera.mac.isNotEmpty)
                          .length ??
                      0;

                  // Skip devices with no cameras that have MAC
                  if (deviceCount == 0) return const SizedBox.shrink();

                  // Always show MAC address to distinguish between devices (unique identifier)
                  final displayLabel = '$macAddress ($deviceCount)';

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(displayLabel),
                      selected: selectedMacAddress == macAddress,
                      onSelected: (_) => _selectMacAddress(macAddress),
                      backgroundColor: Theme.of(context).cardColor,
                      selectedColor: AppTheme.primaryOrange.withOpacity(0.2),
                    ),
                  );
                }).toList(),

                // Unassigned cameras chip (shown last)
                if (groupedCamerasByMac.containsKey('Unassigned'))
                  () {
                    final unassignedCount = groupedCamerasByMac['Unassigned']
                            ?.where((camera) => camera.mac.isNotEmpty)
                            .length ??
                        0;

                    if (unassignedCount == 0) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text('Unassigned ($unassignedCount)'),
                        selected: selectedMacAddress == 'Unassigned',
                        onSelected: (_) => _selectMacAddress('Unassigned'),
                        backgroundColor: Colors.orange.withOpacity(0.1),
                        selectedColor: Colors.orange.withOpacity(0.3),
                      ),
                    );
                  }(),
              ],
            ),
          ),
        );

        // Filter cameras based on selected MAC address and active status
        List<Camera> baseFilteredCameras = [];

        if (selectedMacAddress != null) {
          // Filter by selected MAC address - only show cameras with MAC
          // Also apply search filter
          baseFilteredCameras = (groupedCamerasByMac[selectedMacAddress] ?? [])
              .where((camera) => camera.mac.isNotEmpty)
              .where((camera) => _matchesSearch(camera, searchQuery))
              .toList();
        } else {
          // Show ALL cameras from search-filtered list
          // This includes cameras even if their device is offline
          baseFilteredCameras = filteredBySearch
              .where((camera) =>
                  camera.mac.isNotEmpty && !camera.mac.startsWith('m_'))
              .toList();
        }

        // Apply active filter if needed
        if (showOnlyActive) {
          baseFilteredCameras =
              baseFilteredCameras.where((camera) => camera.connected).toList();
        }

        // Remove duplicate cameras (same MAC address) - keep only one instance per MAC
        final Map<String, Camera> uniqueCamerasByMac = {};
        for (var camera in baseFilteredCameras) {
          if (!uniqueCamerasByMac.containsKey(camera.mac)) {
            uniqueCamerasByMac[camera.mac] = camera;
          }
        }
        baseFilteredCameras = uniqueCamerasByMac.values.toList();

        // Group the filtered cameras by their actual device assignment
        final Map<String, List<Camera>> camerasGroupedByDevice = {};
        for (var camera in baseFilteredCameras) {
          // If a specific device filter is selected, use that device for grouping
          // This ensures camera shows under the selected device when it's on multiple devices
          if (selectedMacAddress != null &&
              camera.currentDevices.containsKey(selectedMacAddress)) {
            final deviceName = _getDeviceName(context, selectedMacAddress!);
            camerasGroupedByDevice
                .putIfAbsent(deviceName, () => [])
                .add(camera);
            print(
                'DEBUG: Camera ${camera.name} (${camera.id}) grouped under selected filter device $deviceName ($selectedMacAddress)');
            continue;
          }

          // Find which device this camera belongs to by checking devicesList
          String? deviceMac;
          String? deviceName;

          for (var device in provider.devicesList) {
            if (device.cameras.any((c) => c.id == camera.id)) {
              deviceMac = device.macKey;
              deviceName = _getDeviceName(context, deviceMac);
              print(
                  'DEBUG: Camera ${camera.name} (${camera.id}) found in device $deviceName ($deviceMac)');
              break;
            }
          }

          // Use device name if found, otherwise try to get from camera's currentDevices
          if (deviceName == null && camera.currentDevices.isNotEmpty) {
            // Use the first device in currentDevices map
            deviceMac = camera.currentDevices.keys.first;
            deviceName = _getDeviceName(context, deviceMac);
            print(
                'DEBUG: Camera ${camera.name} (${camera.id}) using currentDevices first entry $deviceName ($deviceMac)');
          }

          if (deviceName == null) {
            print(
                'DEBUG: Camera ${camera.name} (${camera.id}) has no device assignment - adding to Ungrouped');
          }

          final groupName = deviceName ?? 'Ungrouped Cameras';
          camerasGroupedByDevice.putIfAbsent(groupName, () => []).add(camera);
        }

        return _buildGroupedCameraContent(
            camerasGroupedByDevice, macAddressFilters, searchBar);
      },
    );
  }

  Widget _buildCameraGroupedView() {
    return Consumer3<CameraDevicesProviderOptimized, WebSocketProviderOptimized,
        UserGroupProvider>(
      builder: (context, provider, wsProvider, userGroupProvider, child) {
        // Get authorized camera MACs for current user
        final currentUsername = wsProvider.currentLoggedInUsername;
        Set<String>? authorizedMacs;

        print(
            '[CameraScreen-Grouped] 🔍 Current logged in username: $currentUsername');

        if (currentUsername != null) {
          // Check if user is admin
          final userType = userGroupProvider.getUserType(currentUsername);
          print('[CameraScreen-Grouped] 👤 User type: $userType');

          if (userType == 'admin') {
            // Admin sees all cameras
            authorizedMacs = null;
            print('[CameraScreen-Grouped] 👑 Admin user - showing all cameras');
          } else {
            // Regular user - get authorized cameras
            authorizedMacs =
                userGroupProvider.getUserAuthorizedCameraMacs(currentUsername);
            print(
                '[CameraScreen-Grouped] 🔐 Regular user - authorized MACs: ${authorizedMacs.length} cameras');
            print(
                '[CameraScreen-Grouped] 📷 Authorized camera MACs: $authorizedMacs');
          }
        } else {
          print(
              '[CameraScreen-Grouped] ⚠️ No logged in user - showing all cameras');
        }

        // Get filtered cameras based on authorization
        final allAuthorizedCameras =
            provider.getAuthorizedCameras(authorizedMacs);
        
        // Apply search filter
        final filteredBySearch = searchQuery.isEmpty
            ? allAuthorizedCameras
            : allAuthorizedCameras.where((camera) => _matchesSearch(camera, searchQuery)).toList();
        
        print(
            '[CameraScreen-Grouped] 📊 Total cameras available: ${provider.cameras.length}');
        print(
            '[CameraScreen-Grouped] ✅ Filtered cameras to show: ${filteredBySearch.length}');

        // Build search bar widget
        final searchBar = _buildSearchBar();

        // If loading, show a spinner
        if (provider.isLoading) {
          return Column(
            children: [
              searchBar,
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          );
        }

        // If there are no authorized cameras, show empty state
        if (filteredBySearch.isEmpty) {
          return Column(
            children: [
              searchBar,
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_outlined,
                        size: 64.0,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        searchQuery.isNotEmpty ? 'Sonuç bulunamadı' : 'No cameras found',
                        style: const TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 8.0),
                        Text(
                          '"$searchQuery" için eşleşme yok',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // Get camera groups using the same method as CameraGroupsScreen
        final cameraGroups = provider.cameraGroupsList;

        // Group cameras by their camera groups
        final Map<String, List<Camera>> camerasGroupedByName = {};

        // Use authorized cameras and apply active filter
        List<Camera> filteredAuthorizedCameras = showOnlyActive
            ? filteredBySearch.where((camera) => camera.connected).toList()
            : filteredBySearch;

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
            // Filter by authorization and active status
            List<Camera> filteredCameras = camerasInGroup
                .where((camera) =>
                    filteredBySearch.any((ac) => ac.mac == camera.mac))
                .toList();


            if (showOnlyActive) {
              filteredCameras =
                  filteredCameras.where((camera) => camera.connected).toList();
            }

            camerasGroupedByName[group.name] = filteredCameras;

            // Track assigned cameras
            for (final camera in filteredCameras) {
              assignedCameraIds.add(camera.id);
            }
          }
        }

        // Find ungrouped cameras (not assigned to any group) from authorized cameras
        final ungroupedCameras = filteredAuthorizedCameras
            .where((camera) => !assignedCameraIds.contains(camera.id))
            .toList();

        // Add ungrouped cameras to a separate group if any exist
        if (ungroupedCameras.isNotEmpty) {
          camerasGroupedByName['Ungrouped Cameras'] = ungroupedCameras;
        }

        // Remove empty groups
        camerasGroupedByName.removeWhere((key, value) => value.isEmpty);

        return _buildGroupedCameraContent(camerasGroupedByName, null, searchBar);
      },
    );
  }

  Widget _buildGroupedCameraContent(
      Map<String, List<Camera>> groupedCameras, Widget? filterChips, Widget? searchBar) {
    final sortedGroupNames = groupedCameras.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    
    // İlk yüklemede tüm grupları genişlet
    if (_expandedGroups.isEmpty && sortedGroupNames.isNotEmpty) {
      _expandedGroups.addAll(sortedGroupNames);
    }

    final cameraContent = Expanded(
      child: ListView.builder(
        itemCount: sortedGroupNames.length,
        itemBuilder: (context, groupIndex) {
          final groupName = sortedGroupNames[groupIndex];
          final camerasInGroup = groupedCameras[groupName]!;
          if (camerasInGroup.isEmpty) {
            return const SizedBox.shrink();
          }
          
          final isExpanded = _expandedGroups.contains(groupName);
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: AppTheme.darkSurface,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey<String>(groupName),
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    if (expanded) {
                      _expandedGroups.add(groupName);
                    } else {
                      _expandedGroups.remove(groupName);
                    }
                  });
                },
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Row(
                  children: [
                    Icon(
                      Icons.folder,
                      color: AppTheme.primaryOrange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        groupName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${camerasInGroup.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  if (isGridView)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
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
                    )
                  else
                    ...camerasInGroup.map((camera) => _buildCameraListItem(camera)),
                ],
              ),
            ),
          );
        },
      ),
    );

    return Column(
      children: [
        if (searchBar != null) searchBar,
        if (filterChips != null) filterChips,
        cameraContent,
      ],
    );
  }

  // Build individual camera list item for expansion tile
  Widget _buildCameraListItem(Camera camera) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selectCamera(camera),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                height: 70,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: !_hasMacAddress(camera)
                          ? Colors.grey[800]
                          : Colors.black,
                      child: !_hasMacAddress(camera)
                          ? const Icon(
                              Icons.videocam_off_outlined,
                              size: 32.0,
                              color: Colors.grey,
                            )
                          : camera.mainSnapShot.isNotEmpty
                              ? CameraSnapshotWidget(
                                  snapshotUrl: camera.mainSnapShot,
                                  cameraId: camera.mac,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  showRefreshButton: false,
                                  username: camera.username,
                                  password: camera.password,
                                )
                              : const Icon(
                                  Icons.videocam_off,
                                  size: 32.0,
                                  color: Colors.white54,
                                ),
                    ),
                    if (camera.connected)
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4.0,
                            vertical: 1.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fiber_manual_record,
                                color: Colors.red,
                                size: 8,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
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
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          // Edit camera name button - sol tarafta
                          if (_hasMacAddress(camera))
                            GestureDetector(
                              onTap: () => _showRenameCameraDialog(camera),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              camera.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.0,
                                color: !_hasMacAddress(camera) ? Colors.grey : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            camera.connected ? Icons.link : Icons.link_off,
                            size: 12.0,
                            color: camera.connected ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              camera.ip.isNotEmpty ? camera.ip : camera.mac,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.0,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                          // Recording status badge
                          if (camera.recording)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red, width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.fiber_manual_record, size: 6, color: Colors.red),
                                  const SizedBox(width: 2),
                                  Text(
                                    camera.currentDevices.length > 1
                                        ? 'REC ${camera.recordingCount}/${camera.currentDevices.length}'
                                        : 'REC',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.videocam,
                      size: 20,
                      color: !_hasMacAddress(camera) ? Colors.grey : AppTheme.primaryOrange,
                    ),
                    onPressed: !_hasMacAddress(camera) ? null : () => _openLiveView(camera),
                    tooltip: 'Live View',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.video_library,
                      size: 20,
                      color: !_hasMacAddress(camera) ? Colors.grey : Colors.blue,
                    ),
                    onPressed: !_hasMacAddress(camera) ? null : () => _openRecordView(camera),
                    tooltip: 'Recordings',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Get device name and IP from MAC address
  String _getDeviceName(BuildContext context, String deviceMac) {
    try {
      final provider =
          Provider.of<CameraDevicesProviderOptimized>(context, listen: false);

      // Use MAC address as-is, no formatting
      String normalizedMac = deviceMac;

      // First try direct lookup by key
      if (provider.devices.containsKey(deviceMac)) {
        final device = provider.devices[deviceMac]!;
        String deviceName = '';
        if (device.deviceName?.isNotEmpty == true) {
          deviceName = device.deviceName!;
        } else if (device.deviceType.isNotEmpty) {
          deviceName = device.deviceType;
        } else {
          deviceName = deviceMac;
        }

        if (device.ipv4.isNotEmpty) {
          deviceName += ' (${device.ipv4})';
        }

        print(
            'DEBUG: Device $deviceMac found by key, using full name "$deviceName"');
        return deviceName;
      }

      // Find device by MAC address (case-insensitive comparison)
      for (var device in provider.devices.values) {
        if (device.macAddress.toLowerCase() == normalizedMac.toLowerCase() ||
            device.macKey.toLowerCase() == deviceMac.toLowerCase()) {
          String deviceName = '';
          if (device.deviceName?.isNotEmpty == true) {
            deviceName = device.deviceName!;
          } else if (device.deviceType.isNotEmpty) {
            deviceName = device.deviceType;
          } else {
            // Use MAC as-is for readability
            deviceName = deviceMac;
          }

          // Add IP address if available
          if (device.ipv4.isNotEmpty) {
            deviceName += ' (${device.ipv4})';
          }

          print('DEBUG: Device $deviceMac using full name "$deviceName"');
          return deviceName;
        }
      }

      // If not found, return MAC as-is
      print('DEBUG: Device $deviceMac not found, using MAC as-is');
      return deviceMac;
    } catch (e) {
      // On error, return MAC as-is
      print('DEBUG: Error for device $deviceMac, using MAC as-is');
      return deviceMac;
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
        close(
            context,
            Camera(
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
    final provider =
        Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
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
                ? CameraSnapshotWidget(
                    snapshotUrl: camera.mainSnapShot,
                    cameraId: camera.mac,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    showRefreshButton: false,
                    username: camera.username,
                    password: camera.password,
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

// Extension to add rename functionality to _CamerasScreenState
extension _CamerasScreenRename on _CamerasScreenState {
  void _showRenameCameraDialog(Camera camera) {
    final TextEditingController nameController = TextEditingController(text: camera.displayName);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Row(
          children: [
            Icon(Icons.edit, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Kamera Adını Değiştir', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MAC: ${camera.mac}',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Yeni Kamera Adı',
                labelStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: AppTheme.darkBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryBlue),
                ),
              ),
              onSubmitted: (_) {
                Navigator.pop(dialogContext);
                _submitRename(camera, nameController.text);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _submitRename(camera, nameController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRename(Camera camera, String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamera adı boş olamaz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (trimmedName == camera.displayName) {
      return;
    }
    
    final webSocketProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
    final success = await webSocketProvider.changeCameraName(camera.mac, trimmedName);
    
    if (success) {
      print('[CamerasScreen] Camera rename command sent: ${camera.mac} -> $trimmedName');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kamera adı değiştirme komutu gönderilemedi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
