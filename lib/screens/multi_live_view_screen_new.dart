import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/services.dart';

import '../models/camera_device.dart';
import '../models/camera_layout.dart';
import '../providers/camera_devices_provider.dart';
import '../providers/multi_view_layout_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls_new.dart';

class MultiLiveViewScreenNew extends StatefulWidget {
  const MultiLiveViewScreenNew({Key? key}) : super(key: key);

  @override
  State<MultiLiveViewScreenNew> createState() => _MultiLiveViewScreenNewState();
}

class _MultiLiveViewScreenNewState extends State<MultiLiveViewScreenNew> with AutomaticKeepAliveClientMixin {
  // Map to keep track of active player controllers for each camera slot
  final Map<int, VideoController> _videoControllers = {};
  
  // Map to store the focus state for each camera slot
  final Map<int, bool> _focusedSlots = {};
  
  // Currently selected camera slot for menu actions (configuration, swap, etc.)
  int? _selectedSlot;
  
  // Flag to track whether layout configuration panel is open
  bool _isConfigPanelOpen = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize the layout provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
      
      // Make sure layouts are loaded
      if (!layoutProvider.layoutManager.isLoaded) {
        layoutProvider.layoutManager.loadLayouts();
      }
    });
  }
  
  @override
  void dispose() {
    // Dispose all video controllers
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    super.dispose();
  }
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // Get the available width and height for the layout
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Multi View'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              _isConfigPanelOpen ? Icons.close : Icons.settings,
              color: AppTheme.accentColor,
            ),
            tooltip: _isConfigPanelOpen ? 'Close Layout Settings' : 'Open Layout Settings',
            onPressed: () {
              setState(() {
                _isConfigPanelOpen = !_isConfigPanelOpen;
              });
            },
          ),
        ],
      ),
      body: Consumer2<CameraDevicesProvider, MultiViewLayoutProvider>(
        builder: (context, devicesProvider, layoutProvider, child) {
          // Check if layout data is loaded
          if (layoutProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          // Check if devices are loaded
          if (devicesProvider.isLoading) {
            return const Center(
              child: Text('Loading camera devices...'),
            );
          }
          
          // Get all cameras from all devices
          final allCameras = <Camera>[];
          for (final device in devicesProvider.devices) {
            allCameras.addAll(device.cameras);
          }
          
          // Check if there are any cameras
          if (allCameras.isEmpty) {
            return const Center(
              child: Text('No cameras available.'),
            );
          }
          
          // Get current layout
          final currentLayout = layoutProvider.currentLayout;
          if (currentLayout == null) {
            return const Center(
              child: Text('No layout selected.'),
            );
          }

          return Row(
            children: [
              // Main layout area
              Expanded(
                flex: _isConfigPanelOpen ? 3 : 1,
                child: Container(
                  color: Colors.black,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final layoutWidth = constraints.maxWidth;
                      final layoutHeight = constraints.maxHeight;
                      
                      return Stack(
                        children: [
                          // Each camera slot is positioned according to its percentage values
                          ...currentLayout.cameraLocations.map((location) {
                            // Calculate pixel positions from percentages
                            final left = location.x1 * layoutWidth / 100;
                            final top = location.y1 * layoutHeight / 100;
                            final width = (location.x2 - location.x1) * layoutWidth / 100;
                            final height = (location.y2 - location.y1) * layoutHeight / 100;
                            
                            // Check if a camera is assigned to this slot
                            final cameraId = layoutProvider.getCameraForSlot(location.cameraCode);
                            final camera = cameraId != null 
                                ? allCameras.firstWhere(
                                    (camera) => camera.id == cameraId,
                                    orElse: () => null,
                                  )
                                : null;
                            
                            // Create or get the video controller for this slot
                            if (camera != null && !_videoControllers.containsKey(location.cameraCode)) {
                              _initializeVideoController(location.cameraCode, camera);
                            }
                            
                            final bool isFocused = _focusedSlots[location.cameraCode] ?? false;
                            
                            return Positioned(
                              left: left,
                              top: top,
                              width: width,
                              height: height,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    // Clear previous selections
                                    _focusedSlots.clear();
                                    // Set this slot as focused
                                    _focusedSlots[location.cameraCode] = true;
                                    // Set as selected slot for menu actions
                                    _selectedSlot = location.cameraCode;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isFocused 
                                          ? AppTheme.accentColor 
                                          : Colors.grey.shade800,
                                      width: isFocused ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Camera video or placeholder
                                      camera != null && _videoControllers.containsKey(location.cameraCode)
                                          ? ClipRect(
                                              child: Video(
                                                controller: _videoControllers[location.cameraCode]!,
                                                controls: NoVideoControls,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.videocam_off,
                                                    color: Colors.grey.shade700,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    camera == null 
                                                        ? 'No Camera Assigned'
                                                        : 'Camera ${camera.name} (Loading...)',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade300,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                      
                                      // Camera info overlay
                                      if (camera != null)
                                        Positioned(
                                          left: 8,
                                          top: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              camera.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      
                                      // Video controls for focused slot
                                      if (isFocused && camera != null && _videoControllers.containsKey(location.cameraCode))
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: VideoControlsNew(
                                            controller: _videoControllers[location.cameraCode]!,
                                            onFullScreen: () {
                                              _toggleFullScreen(location.cameraCode, camera);
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),
                ),
              ),
              
              // Config and camera selection panel
              if (_isConfigPanelOpen)
                Expanded(
                  flex: 1,
                  child: Container(
                    color: AppTheme.darkSurface,
                    child: Column(
                      children: [
                        // Layout selector
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Layout',
                                style: TextStyle(
                                  color: AppTheme.darkTextPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<int>(
                                value: currentLayout.layoutCode,
                                isExpanded: true,
                                dropdownColor: AppTheme.darkBackground,
                                style: TextStyle(
                                  color: AppTheme.darkTextPrimary,
                                ),
                                underline: Container(
                                  height: 1,
                                  color: AppTheme.accentColor.withOpacity(0.5),
                                ),
                                onChanged: (value) {
                                  if (value != null) {
                                    layoutProvider.setLayout(value);
                                    
                                    // Reset focused state
                                    setState(() {
                                      _focusedSlots.clear();
                                      _selectedSlot = null;
                                    });
                                    
                                    // Dispose controllers for slots that are no longer used
                                    _disposeUnusedControllers(currentLayout);
                                  }
                                },
                                items: layoutProvider.layoutManager.layouts
                                    .map((layout) => DropdownMenuItem<int>(
                                          value: layout.layoutCode,
                                          child: Text(
                                            'Layout ${layout.layoutCode} (${layout.maxCameraNumber} cameras)',
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        
                        // Selected Slot info and actions
                        if (_selectedSlot != null)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Camera Slot $_selectedSlot',
                                  style: TextStyle(
                                    color: AppTheme.darkTextPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                
                                // Get the currently assigned camera for this slot
                                ..._buildSlotActions(_selectedSlot!, layoutProvider, allCameras),
                              ],
                            ),
                          ),
                          
                        const Divider(height: 1),
                        
                        // Global actions
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Global Actions',
                                style: TextStyle(
                                  color: AppTheme.darkTextPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Clear all camera assignments
                              ElevatedButton.icon(
                                icon: const Icon(Icons.clear_all),
                                label: const Text('Clear All Assignments'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade800,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  // Confirm with dialog
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Clear All Assignments'),
                                      content: const Text('Are you sure you want to clear all camera assignments?'),
                                      actions: [
                                        TextButton(
                                          child: const Text('Cancel'),
                                          onPressed: () => Navigator.of(context).pop(),
                                        ),
                                        TextButton(
                                          child: const Text('Clear All'),
                                          onPressed: () {
                                            // Clear all assignments
                                            layoutProvider.clearAllAssignments();
                                            
                                            // Dispose all controllers
                                            for (final controller in _videoControllers.values) {
                                              controller.dispose();
                                            }
                                            _videoControllers.clear();
                                            
                                            // Close dialog
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        // Available Cameras List
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available Cameras',
                                  style: TextStyle(
                                    color: AppTheme.darkTextPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: allCameras.length,
                                    itemBuilder: (context, index) {
                                      final camera = allCameras[index];
                                      
                                      // Check if this camera is already assigned to a slot
                                      final isAssigned = layoutProvider.cameraAssignments.containsValue(camera.id);
                                      
                                      return ListTile(
                                        leading: Icon(
                                          isAssigned ? Icons.videocam : Icons.videocam_off,
                                          color: isAssigned 
                                              ? AppTheme.accentColor
                                              : AppTheme.darkTextSecondary,
                                        ),
                                        title: Text(
                                          camera.name,
                                          style: TextStyle(
                                            color: AppTheme.darkTextPrimary,
                                          ),
                                        ),
                                        subtitle: Text(
                                          camera.isConnected
                                              ? 'Online - ${camera.brand}'
                                              : 'Offline',
                                          style: TextStyle(
                                            color: camera.isConnected
                                                ? Colors.green.shade300
                                                : Colors.red.shade300,
                                          ),
                                        ),
                                        trailing: isAssigned
                                            ? Text(
                                                'Assigned',
                                                style: TextStyle(
                                                  color: AppTheme.darkTextSecondary,
                                                ),
                                              )
                                            : null,
                                        onTap: () {
                                          // If a slot is selected, assign this camera to it
                                          if (_selectedSlot != null) {
                                            // Assign camera to selected slot
                                            layoutProvider.assignCamera(_selectedSlot!, camera.id);
                                            
                                            // Initialize or update the video controller
                                            _initializeVideoController(_selectedSlot!, camera);
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
  
  // Build the actions for a selected slot
  List<Widget> _buildSlotActions(int slotCode, MultiViewLayoutProvider layoutProvider, List<Camera> allCameras) {
    final cameraId = layoutProvider.getCameraForSlot(slotCode);
    final camera = cameraId != null 
        ? allCameras.firstWhere(
            (camera) => camera.id == cameraId,
            orElse: () => null,
          )
        : null;
    
    return [
      if (camera != null)
        Card(
          color: AppTheme.darkBackground,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned Camera: ${camera.name}',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'IP: ${camera.ip}',
                  style: TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Status: ${camera.isConnected ? "Online" : "Offline"}',
                  style: TextStyle(
                    color: camera.isConnected
                        ? Colors.green.shade300
                        : Colors.red.shade300,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Stream: ${camera.subUri.isNotEmpty ? "Available" : "Not Available"}',
                  style: TextStyle(
                    color: camera.subUri.isNotEmpty
                        ? Colors.green.shade300
                        : Colors.yellow.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      
      const SizedBox(height: 8),
      
      Row(
        children: [
          if (camera != null)
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.remove_circle),
                label: const Text('Remove'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  // Remove the camera from this slot
                  layoutProvider.removeCamera(slotCode);
                  
                  // Dispose the video controller
                  if (_videoControllers.containsKey(slotCode)) {
                    _videoControllers[slotCode]!.dispose();
                    _videoControllers.remove(slotCode);
                  }
                },
              ),
            ),
          
          if (camera != null)
            const SizedBox(width: 8),
          
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(camera != null ? Icons.swap_horiz : Icons.add),
              label: Text(camera != null ? 'Change' : 'Assign Camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                // The camera will be assigned when a camera is tapped in the list
                // So no action needed here, just highlight the instructions
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      camera != null
                          ? 'Tap on a camera from the list to replace the current assignment'
                          : 'Tap on a camera from the list to assign it to this slot',
                    ),
                    backgroundColor: AppTheme.accentColor,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ];
  }
  
  // Initialize or update a video controller for a camera slot
  void _initializeVideoController(int slotCode, Camera camera) {
    // Dispose the existing controller if it exists
    if (_videoControllers.containsKey(slotCode)) {
      _videoControllers[slotCode]!.dispose();
      _videoControllers.remove(slotCode);
    }
    
    // Check if camera has a valid stream URI
    if (camera.rtspUri.isEmpty) {
      // No valid URI, don't create a controller
      print('No valid RTSP URI for camera ${camera.name}');
      return;
    }
    
    // Create a new controller
    final controller = VideoController(
      configuration: const VideoControllerConfiguration(
        // No controls, we'll use our own
        controls: NoVideoControls,
        // Improved buffer size for smoother playback
        bufferSize: 50 * 1024 * 1024,
        autoHideControls: false,
      ),
    );
    
    // Initialize the player with the RTSP URI
    controller.player.open(
      Media(camera.rtspUri),
      play: true,
    );
    
    // Store the controller
    _videoControllers[slotCode] = controller;
    
    // Trigger rebuild
    setState(() {});
  }
  
  // Dispose controllers for slots that are no longer in the layout
  void _disposeUnusedControllers(CameraLayout layout) {
    // Get all slot codes in the current layout
    final validSlotCodes = layout.cameraLocations.map((loc) => loc.cameraCode).toSet();
    
    // Find controllers for slots that are no longer in the layout
    final slotsToDispose = _videoControllers.keys
        .where((slotCode) => !validSlotCodes.contains(slotCode))
        .toList();
    
    // Dispose these controllers
    for (final slotCode in slotsToDispose) {
      _videoControllers[slotCode]!.dispose();
      _videoControllers.remove(slotCode);
    }
  }
  
  // Toggle fullscreen mode for a camera
  void _toggleFullScreen(int slotCode, Camera camera) {
    // We can implement fullscreen mode here if needed
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fullscreen view for ${camera.name} not implemented yet.'),
        backgroundColor: AppTheme.accentColor,
      ),
    );
  }
}
