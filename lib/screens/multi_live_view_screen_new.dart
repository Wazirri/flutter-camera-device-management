import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
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
      controller.player.dispose();
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
          for (final device in devicesProvider.devices.values) {
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
                                    orElse: () => Camera(),
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
                                                fill: true,
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
                                              camera.name ?? 'Unknown Camera',
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
                                
                                // Camera selector for the slot
                                DropdownButton<String?>(
                                  value: layoutProvider.getCameraForSlot(_selectedSlot!),
                                  isExpanded: true,
                                  dropdownColor: AppTheme.darkBackground,
                                  style: TextStyle(
                                    color: AppTheme.darkTextPrimary,
                                  ),
                                  underline: Container(
                                    height: 1,
                                    color: AppTheme.accentColor.withOpacity(0.5),
                                  ),
                                  hint: Text(
                                    'Select a camera',
                                    style: TextStyle(
                                      color: AppTheme.darkTextSecondary,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    // Get current camera to check if we need to dispose
                                    final oldCameraId = layoutProvider.getCameraForSlot(_selectedSlot!);
                                    
                                    // Store the camera selection in the layout provider
                                    layoutProvider.setCameraForSlot(_selectedSlot!, value);
                                    
                                    // If the camera selection changed, dispose the old controller
                                    if (oldCameraId != value && _videoControllers.containsKey(_selectedSlot)) {
                                      _videoControllers[_selectedSlot!]!.player.dispose();
                                      _videoControllers.remove(_selectedSlot);
                                    }
                                    
                                    // Initialize the new controller if a camera was selected
                                    if (value != null) {
                                      final camera = allCameras.firstWhere(
                                        (camera) => camera.id == value,
                                        orElse: () => Camera(),
                                      );
                                      _initializeVideoController(_selectedSlot!, camera);
                                    }
                                    
                                    setState(() {});
                                  },
                                  items: [
                                    // "None" option to clear the slot
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text(
                                        'None (Clear Slot)',
                                        style: TextStyle(
                                          color: AppTheme.darkTextSecondary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                    // All available cameras
                                    ...allCameras.map((camera) => DropdownMenuItem<String?>(
                                          value: camera.id,
                                          child: Text(
                                            camera.name ?? 'Unknown Camera',
                                          ),
                                        )),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Camera swap buttons (for quick swapping)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...currentLayout.cameraLocations.map((loc) {
                                      // Skip the current slot
                                      if (loc.cameraCode == _selectedSlot) {
                                        return const SizedBox.shrink();
                                      }
                                      
                                      // Get camera assigned to this slot
                                      final cameraId = layoutProvider.getCameraForSlot(loc.cameraCode);
                                      final camera = cameraId != null
                                          ? allCameras.firstWhere(
                                              (camera) => camera.id == cameraId,
                                              orElse: () => Camera(),
                                            )
                                          : null;
                                      
                                      return GestureDetector(
                                        onTap: () {
                                          // Swap cameras between slots
                                          layoutProvider.swapCameras(_selectedSlot!, loc.cameraCode);
                                          
                                          // Dispose controllers to reinitialize with new assignments
                                          if (_videoControllers.containsKey(_selectedSlot)) {
                                            _videoControllers[_selectedSlot!]!.player.dispose();
                                            _videoControllers.remove(_selectedSlot);
                                          }
                                          
                                          if (_videoControllers.containsKey(loc.cameraCode)) {
                                            _videoControllers[loc.cameraCode]!.player.dispose();
                                            _videoControllers.remove(loc.cameraCode);
                                          }
                                          
                                          setState(() {});
                                        },
                                        child: Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: AppTheme.darkBackground,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: AppTheme.darkDivider,
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: Text(
                                                  '${loc.cameraCode}',
                                                  style: TextStyle(
                                                    color: AppTheme.darkTextPrimary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (camera != null)
                                                Positioned(
                                                  right: 4,
                                                  bottom: 4,
                                                  child: Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: AppTheme.accentColor,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        
                        const Divider(),
                        
                        // Layout information
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Layout Information',
                                style: TextStyle(
                                  color: AppTheme.darkTextPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Layout Code: ${currentLayout.layoutCode}',
                                style: TextStyle(
                                  color: AppTheme.darkTextSecondary,
                                ),
                              ),
                              Text(
                                'Max Cameras: ${currentLayout.maxCameraNumber}',
                                style: TextStyle(
                                  color: AppTheme.darkTextSecondary,
                                ),
                              ),
                              Text(
                                'Camera Slots: ${currentLayout.cameraLocations.length}',
                                style: TextStyle(
                                  color: AppTheme.darkTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Assigned Cameras: ${layoutProvider.getAssignedCameraCount()}',
                                style: TextStyle(
                                  color: AppTheme.darkTextSecondary,
                                ),
                              ),
                            ],
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
  
  /// Initialize a video controller for a specific camera slot
  void _initializeVideoController(int slotCode, Camera camera) {
    // Dispose the existing controller if it exists
    if (_videoControllers.containsKey(slotCode)) {
      _videoControllers[slotCode]!.player.dispose();
      _videoControllers.remove(slotCode);
    }
    
    // Check if camera has a valid stream URI
    if (camera.rtspUri == null || camera.rtspUri!.isEmpty) {
      // No valid URI, don't create a controller
      print('No valid RTSP URI for camera ${camera.name}');
      return;
    }
    
    // Create a new controller with a player
    final player = Player();
    final controller = VideoController(player);
    
    // Initialize the player with the RTSP URI
    player.open(
      Media(camera.rtspUri!),
    );
    
    // Store the controller
    _videoControllers[slotCode] = controller;
    
    // Trigger rebuild
    setState(() {});
  }
  
  /// Dispose controllers for slots that are no longer used in the current layout
  void _disposeUnusedControllers(CameraLayout layout) {
    // Get all camera slot codes in the current layout
    final activeCodes = layout.cameraLocations.map((loc) => loc.cameraCode).toList();
    
    // Find controllers that don't correspond to any active slot
    final unusedCodes = _videoControllers.keys.where((code) => !activeCodes.contains(code)).toList();
    
    // Dispose those controllers
    for (final slotCode in unusedCodes) {
      _videoControllers[slotCode]!.player.dispose();
      _videoControllers.remove(slotCode);
    }
  }
  
  /// Toggle full screen mode for a specific camera
  void _toggleFullScreen(int slotCode, Camera camera) {
    // Implement full screen functionality
    // This could open a new screen or expand the current slot
    // For now, we'll just print a debug message
    print('Toggle full screen for camera ${camera.name} in slot $slotCode');
    
    // Example implementation: could navigate to a dedicated full screen view
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) => FullScreenCameraView(
    //       camera: camera,
    //     ),
    //   ),
    // );
  }
}
