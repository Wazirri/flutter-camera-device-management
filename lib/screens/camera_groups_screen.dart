import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/camera_device.dart';
import '../models/camera_group.dart';
import '../providers/camera_devices_provider_optimized.dart';
import '../theme/app_theme.dart';
import 'live_view_screen.dart';
import 'multi_recordings_screen.dart';

import '../widgets/camera_details_bottom_sheet.dart';

class CameraGroupsScreen extends StatefulWidget {
  const CameraGroupsScreen({Key? key}) : super(key: key);

  @override
  _CameraGroupsScreenState createState() => _CameraGroupsScreenState();
}

class _CameraGroupsScreenState extends State<CameraGroupsScreen> {
  // Currently expanded group names (multiple groups can be expanded)
  final Set<String> _expandedGroupNames = <String>{};
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
      if (_expandedGroupNames.contains(groupName)) {
        _expandedGroupNames.remove(groupName); // Collapse if already expanded
      } else {
        _expandedGroupNames.add(groupName); // Expand this group
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
        builder: (context) => const MultiRecordingsScreen(),
      ),
    );
  }

  // Remove camera from group
  Future<void> _removeCameraFromGroup(Camera camera, String groupName) async {    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Camera from Group'),
        content: Text(
          'Are you sure you want to remove "${camera.name}" from group "$groupName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });
      
      final provider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
      bool success = await provider.removeCameraFromGroupViaWebSocket(camera.mac, groupName);
      
      setState(() {
        _isLoading = false;
      });
      
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove camera from group'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera removed from group successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // Show add group dialog
  void _showAddGroupDialog() {
    String groupName = '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Camera Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter group name',
                prefixIcon: Icon(Icons.group),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                groupName = value.trim();
              },
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context);
                  _createGroup(value.trim());
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Group names should be unique and descriptive.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (groupName.isNotEmpty) {
                Navigator.pop(context);
                _createGroup(groupName);
              }
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }

  // Create a new camera group
  void _createGroup(String groupName) async {
    final provider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    // Check if group already exists
    final existingGroups = provider.cameraGroupsList;
    if (existingGroups.any((group) => group.name.toLowerCase() == groupName.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group "$groupName" already exists'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Create the group using provider
      provider.createGroup(groupName);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group "$groupName" created successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the groups list
      await _loadCameraGroups();
      
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating group: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
    final bool isExpanded = _expandedGroupNames.contains(group.name);
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
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _selectCamera(camera),
                        child: Row(
                          children: [
                            // Camera thumbnail/preview
                            SizedBox(
                              width: 120,
                              height: 80,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(
                                    color: camera.mac.isEmpty ? Colors.grey[800] : Colors.black,
                                    child: camera.mac.isEmpty
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
                            // Camera details
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Camera name and MAC status
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
                                              color: camera.mac.isEmpty ? Colors.grey : null,
                                            ),
                                          ),
                                        ),
                                        if (camera.mac.isEmpty)
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
                                    // Connection status
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
                                          camera.ip.isNotEmpty ? camera.ip : 'No IP',
                                          style: TextStyle(
                                            fontSize: 12.0,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Brand and device info
                                    Row(
                                      children: [
                                        if (camera.brand.isNotEmpty) ...[
                                          Icon(
                                            Icons.business,
                                            size: 12.0,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            camera.brand,
                                            style: const TextStyle(
                                              fontSize: 12.0,
                                              color: Colors.blue,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                        ],
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
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Action buttons
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.videocam,
                                    color: camera.mac.isEmpty ? Colors.grey : AppTheme.primaryBlue,
                                  ),
                                  onPressed: camera.mac.isEmpty ? null : () => _openLiveView(camera),
                                  tooltip: camera.mac.isEmpty ? 'No MAC Address' : 'Live View',
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.video_library,
                                    color: camera.mac.isEmpty ? Colors.grey : AppTheme.primaryOrange,
                                  ),
                                  onPressed: camera.mac.isEmpty ? null : () => _openRecordView(camera),
                                  tooltip: camera.mac.isEmpty ? 'No MAC Address' : 'Recordings',
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.remove_circle_outline,
                                    color: camera.mac.isEmpty ? Colors.grey : Colors.red,
                                  ),
                                  onPressed: camera.mac.isEmpty ? null : () => _removeCameraFromGroup(camera, group.name),
                                  tooltip: camera.mac.isEmpty ? 'No MAC Address' : 'Remove from Group',
                                ),
                              ],
                            ),
                          ],
                        ),
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
    final provider = Provider.of<CameraDevicesProviderOptimized>(context);
    final cameraGroups = provider.cameraGroupsList;
    
    print("CameraGroupsScreen: Rendering ${cameraGroups.length} groups: ${cameraGroups.map((g) => g.name).toList()}");
    
    // For each group, get the cameras in that group
    final Map<CameraGroup, List<Camera>> groupedCameras = {};
    for (final group in cameraGroups) {
      final camerasInGroup = provider.getCamerasInGroup(group.name);
      groupedCameras[group] = camerasInGroup;
      print("CameraGroupsScreen: Group '${group.name}' has ${camerasInGroup.length} cameras");
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
          // Add group button
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Camera Group',
            onPressed: _showAddGroupDialog,
          ),
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.group_add,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No camera groups found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create your first camera group to organize your cameras',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddGroupDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Camera Group'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : filteredGroups.isEmpty 
                  ? Center(
                      child: Text(
                        'No camera groups match "$_searchQuery"',
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
