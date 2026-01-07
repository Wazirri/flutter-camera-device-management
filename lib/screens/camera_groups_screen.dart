import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/camera_device.dart';
import '../models/camera_group.dart';
import '../providers/camera_devices_provider.dart';
import '../providers/user_group_provider.dart';
import '../providers/websocket_provider.dart';
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

  // Show dialog to assign cameras to a group
  Future<void> _showAssignCamerasDialog(CameraGroup group) async {
    final cameraProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    // Get all available cameras
    final allCameras = cameraProvider.cameras.where((c) => c.mac.isNotEmpty && !c.mac.startsWith('m_')).toList();
    
    // Track selected cameras (initially select cameras already in the group)
    final selectedCameraMacs = Set<String>.from(group.cameraMacs);
    
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _CameraSelectionDialog(
        groupName: group.name,
        allCameras: allCameras,
        initialSelectedMacs: selectedCameraMacs,
      ),
    );
    
    if (result != null) {
      // Send camera assignments to server via WebSocket
      await _assignCamerasToGroup(group.name, result);
    }
  }

  // Assign cameras to group by sending WebSocket messages
  Future<void> _assignCamerasToGroup(String groupName, Set<String> selectedCameraMacs) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final wsProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
      
      print('CDP: Assigning ${selectedCameraMacs.length} cameras to group $groupName');
      
      // Send individual WebSocket messages for each camera
      int successCount = 0;
      int failCount = 0;
      
      for (final cameraMac in selectedCameraMacs) {
        try {
          // Send ADD_GROUP_TO_CAM command for each camera
          // Format: ADD_GROUP_TO_CAM <camera_mac> <group_name>
          // Example: ADD_GROUP_TO_CAM e8:b7:23:0c:11:b2 timko1
          final success = await wsProvider.sendAddGroupToCamera(cameraMac, groupName);
          
          if (success) {
            successCount++;
            print('CDP: ✅ Successfully assigned camera $cameraMac to group $groupName');
          } else {
            failCount++;
            print('CDP: ❌ Failed to assign camera $cameraMac to group $groupName');
          }
          
          // Small delay between messages to avoid overwhelming the server
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          failCount++;
          print('CDP: ❌ Error assigning camera $cameraMac: $e');
        }
      }
      
      // Show result
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount kamera başarıyla $groupName grubuna atandı'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount başarılı, $failCount başarısız'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      await _loadCameraGroups();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Build a camera group expansion panel
  Widget _buildCameraGroup(BuildContext context, CameraGroup group, List<Camera> camerasInGroup) {
    final bool isExpanded = _expandedGroupNames.contains(group.name);
    
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
    
    // Apply active filter only if enabled
    if (_showOnlyActive) {
      filteredCameras = filteredCameras.where((camera) => camera.connected).toList();
    }
    
    final String subtitle = '${filteredCameras.length} camera${filteredCameras.length != 1 ? 's' : ''}';

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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Assign cameras button
                IconButton(
                  icon: const Icon(Icons.video_library),
                  tooltip: 'Kamera Eşleştir',
                  onPressed: () => _showAssignCamerasDialog(group),
                ),
                // Expand/collapse icon
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                ),
              ],
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
    final cameraProvider = Provider.of<CameraDevicesProviderOptimized>(context);
    final userGroupProvider = Provider.of<UserGroupProvider>(context);
    
    // Get groups from UserGroupProvider (permission/user groups)
    final cameraGroups = userGroupProvider.groupsList;
    
    print("CameraGroupsScreen: Rendering ${cameraGroups.length} groups from UserGroupProvider: ${cameraGroups.map((g) => g.name).toList()}");
    
    // For each group, get the cameras in that group
    // Use group name as key instead of CameraGroup object to avoid instance mismatch
    final Map<String, List<Camera>> groupedCameras = {};
    for (final group in cameraGroups) {
      // Get cameras by MACs listed in the group
      final camerasInGroup = group.cameraMacs
          .map((mac) => cameraProvider.cameras.firstWhere(
                (camera) => camera.mac == mac,
                orElse: () => Camera(
                  mac: mac,
                  name: 'Unknown',
                  ip: '',
                  index: -1,
                  connected: false,
                ),
              ))
          .where((camera) => camera.name != 'Unknown') // Filter out not found cameras
          .toList();
      groupedCameras[group.name] = camerasInGroup;
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
        final camerasInGroup = groupedCameras[group.name] ?? [];
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.group_work,
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
                        'Camera groups will appear here when available',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
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
                          final camerasInGroup = groupedCameras[group.name] ?? [];
                          return _buildCameraGroup(context, group, camerasInGroup);
                        },
                      ),
                    ),
    );
  }
}

// Dialog for selecting cameras to assign to a group
class _CameraSelectionDialog extends StatefulWidget {
  final String groupName;
  final List<Camera> allCameras;
  final Set<String> initialSelectedMacs;

  const _CameraSelectionDialog({
    required this.groupName,
    required this.allCameras,
    required this.initialSelectedMacs,
  });

  @override
  _CameraSelectionDialogState createState() => _CameraSelectionDialogState();
}

class _CameraSelectionDialogState extends State<_CameraSelectionDialog> {
  late Set<String> _selectedMacs;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedMacs = Set<String>.from(widget.initialSelectedMacs);
  }

  @override
  Widget build(BuildContext context) {
    // Filter cameras by search query
    final filteredCameras = widget.allCameras.where((camera) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return camera.name.toLowerCase().contains(query) ||
          camera.ip.toLowerCase().contains(query) ||
          camera.mac.toLowerCase().contains(query);
    }).toList();

    return Dialog(
      backgroundColor: AppTheme.darkBackground,
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.video_library, color: AppTheme.primaryOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kamera Eşleştir',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Grup: ${widget.groupName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Kamera ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 12),

            // Selection info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.primaryOrange),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedMacs.length} kamera seçildi',
                    style: TextStyle(color: AppTheme.primaryOrange),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedMacs.clear();
                      });
                    },
                    child: const Text('Tümünü Temizle'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedMacs.addAll(filteredCameras.map((c) => c.mac));
                      });
                    },
                    child: const Text('Tümünü Seç'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Camera list
            Expanded(
              child: filteredCameras.isEmpty
                  ? const Center(
                      child: Text('Kamera bulunamadı'),
                    )
                  : ListView.builder(
                      itemCount: filteredCameras.length,
                      itemBuilder: (context, index) {
                        final camera = filteredCameras[index];
                        final isSelected = _selectedMacs.contains(camera.mac);

                        return Card(
                          color: isSelected
                              ? AppTheme.primaryOrange.withOpacity(0.1)
                              : Colors.grey[850],
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedMacs.add(camera.mac);
                                } else {
                                  _selectedMacs.remove(camera.mac);
                                }
                              });
                            },
                            title: Text(
                              camera.name.isEmpty ? 'Unknown Camera' : camera.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('MAC: ${camera.mac}'),
                                if (camera.ip.isNotEmpty) Text('IP: ${camera.ip}'),
                                if (camera.brand.isNotEmpty) Text('Brand: ${camera.brand}'),
                              ],
                            ),
                            secondary: Icon(
                              camera.connected ? Icons.videocam : Icons.videocam_off,
                              color: camera.connected ? Colors.green : Colors.grey,
                            ),
                            activeColor: AppTheme.primaryOrange,
                          ),
                        );
                      },
                    ),
            ),

            const Divider(),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(_selectedMacs);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
