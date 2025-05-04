import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/camera_device.dart';
import '../models/camera_group.dart';
import '../providers/camera_devices_provider.dart';
import '../theme/app_theme.dart';
import 'live_view_screen.dart';
import 'record_view_screen.dart';
import '../widgets/camera_details_bottom_sheet.dart';

class CameraGroupsScreen extends StatefulWidget {
  const CameraGroupsScreen({Key? key}) : super(key: key);

  @override
  _CameraGroupsScreenState createState() => _CameraGroupsScreenState();
}

class _CameraGroupsScreenState extends State<CameraGroupsScreen> {
  // Currently selected group name
  String? _expandedGroupName;
  bool _isLoading = false;
  String _searchQuery = '';
  bool _showOnlyActive = false;

  @override
  void initState() {
    super.initState();
    _loadCameraGroups();
  }

  // Refresh camera groups data
  Future<void> _loadCameraGroups() async {
    setState(() {
      _isLoading = true;
    });

    // Give time for the provider to update
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _isLoading = false;
    });
  }

  // Select a group to expand and show its cameras
  void _toggleGroup(String groupName) {
    setState(() {
      if (_expandedGroupName == groupName) {
        _expandedGroupName = null; // Collapse if already expanded
      } else {
        _expandedGroupName = groupName; // Expand this group
      }
    });
  }

  // Select a camera to show details
  void _selectCamera(Camera camera) {
    // Show camera details in a bottom sheet
    _showCameraDetails(camera);
  }

  // Show camera details in a bottom sheet
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

  // Open live view for a camera
  void _openLiveView(Camera camera) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveViewScreen(camera: camera),
      ),
    );
  }

  // Open record view for a camera
  void _openRecordView(Camera camera) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordViewScreen(camera: camera),
      ),
    );
  }

  // Toggle the "only show active cameras" filter
  void _toggleActiveFilter() {
    setState(() {
      _showOnlyActive = !_showOnlyActive;
    });
  }

  // Update search query
  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  // Build a camera group expansion panel
  Widget _buildCameraGroup(BuildContext context, CameraGroup group, List<Camera> camerasInGroup) {
    final bool isExpanded = _expandedGroupName == group.name;
    final String subtitle = '${camerasInGroup.length} camera${camerasInGroup.length != 1 ? 's' : ''}';
    
    // Filter cameras by search query and active status if necessary
    List<Camera> filteredCameras = camerasInGroup;
    if (_searchQuery.isNotEmpty) {
      final String lowercaseQuery = _searchQuery.toLowerCase();
      filteredCameras = filteredCameras.where((camera) => 
        camera.name.toLowerCase().contains(lowercaseQuery) || 
        camera.ip.toLowerCase().contains(lowercaseQuery) ||
        camera.brand.toLowerCase().contains(lowercaseQuery)
      ).toList();
    }
    
    if (_showOnlyActive) {
      filteredCameras = filteredCameras.where((camera) => camera.connected).toList();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        children: [
          // Group header
          ListTile(
            title: Text(
              group.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(subtitle),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            ),
            onTap: () => _toggleGroup(group.name),
          ),
          
          // Expanded cameras list
          if (isExpanded)
            filteredCameras.isEmpty 
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No cameras in this group match your filters',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredCameras.length,
                  itemBuilder: (context, index) {
                    final camera = filteredCameras[index];
                    
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        leading: Icon(
                          camera.connected ? Icons.videocam : Icons.videocam_off,
                          color: camera.connected ? Colors.green : Colors.red,
                          size: 28,
                        ),
                        title: Text(
                          camera.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${camera.ip} • ${camera.brand}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Live View button
                            IconButton(
                              icon: const Icon(Icons.play_arrow, color: AppTheme.primaryBlue),
                              onPressed: () => _openLiveView(camera),
                              tooltip: 'Live View',
                            ),
                            // Playback button
                            IconButton(
                              icon: const Icon(Icons.history, color: AppTheme.primaryOrange),
                              onPressed: () => _openRecordView(camera),
                              tooltip: 'Recordings',
                            ),
                          ],
                        ),
                        onTap: () => _selectCamera(camera),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CameraDevicesProvider>(context);
    final cameraGroups = provider.cameraGroupsList;
    
    // For each group, get the cameras in that group
    final Map<CameraGroup, List<Camera>> groupedCameras = {};
    for (final group in cameraGroups) {
      final camerasInGroup = provider.getCamerasInGroup(group.name);
      groupedCameras[group] = camerasInGroup;
    }
    
    // Filter groups based on search query
    List<CameraGroup> filteredGroups = cameraGroups;
    if (_searchQuery.isNotEmpty) {
      final String lowercaseQuery = _searchQuery.toLowerCase();
      filteredGroups = filteredGroups.where((group) {
        // Check if group name matches
        if (group.name.toLowerCase().contains(lowercaseQuery)) {
          return true;
        }
        
        // Check if any camera in the group matches
        final camerasInGroup = groupedCameras[group] ?? [];
        return camerasInGroup.any((camera) => 
          camera.name.toLowerCase().contains(lowercaseQuery) || 
          camera.ip.toLowerCase().contains(lowercaseQuery)
        );
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Groups'),
        actions: [
          // Search field
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Camera Groups',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Search Camera Groups'),
                  content: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter group or camera name',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _updateSearchQuery,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _updateSearchQuery('');
                      },
                      child: const Text('CLEAR'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('DONE'),
                    ),
                  ],
                ),
              );
            },
          ),
          // Filter toggle
          IconButton(
            icon: Icon(
              _showOnlyActive 
                ? Icons.filter_alt
                : Icons.filter_alt_outlined,
            ),
            tooltip: 'Show Only Active Cameras',
            onPressed: _toggleActiveFilter,
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Camera Groups',
            onPressed: _loadCameraGroups,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : cameraGroups.isEmpty
              ? const Center(
                  child: Text(
                    'No camera groups found. Add groups in the settings.',
                    textAlign: TextAlign.center,
                  ),
                )
              : filteredGroups.isEmpty 
                  ? Center(
                      child: Text(
                        'No camera groups match "${_searchQuery}"',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCameraGroups,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: filteredGroups.length,
                        itemBuilder: (context, index) {
                          final group = filteredGroups[index];
                          final camerasInGroup = groupedCameras[group] ?? [];
                          return _buildCameraGroup(context, group, camerasInGroup);
                        },
                      ),
                    ),
    );
  }
}
