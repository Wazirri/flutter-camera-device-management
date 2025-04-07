#!/usr/bin/env python3

def fix_multiview_layout():
    fixed_code = """import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/camera_devices_provider.dart';
import '../providers/multi_view_layout_provider.dart';
import '../models/camera_device.dart';
import '../models/camera_layout.dart';
import '../utils/responsive_helper.dart';
import 'dart:math' as math;

class MultiLiveViewScreen extends StatefulWidget {
  const MultiLiveViewScreen({Key? key}) : super(key: key);

  @override
  State<MultiLiveViewScreen> createState() => _MultiLiveViewScreenState();
}

class _MultiLiveViewScreenState extends State<MultiLiveViewScreen> {
  // Maximum number of cameras per page
  static const int maxCamerasPerPage = 20;
  
  // State variables
  List<Camera> _availableCameras = [];
  final List<Camera?> _selectedCameras = List.filled(maxCamerasPerPage, null);
  final List<Player> _players = [];
  final List<VideoController> _controllers = [];
  final List<bool> _loadingStates = List.filled(maxCamerasPerPage, false);
  final List<bool> _errorStates = List.filled(maxCamerasPerPage, false);
  int _gridColumns = 4; // Default grid columns
  CameraLayout _currentLayout = CameraLayout(name: 'Default', id: 4, rows: 5, columns: 4, slots: 20, description: 'Default layout');
  
  @override
  void initState() {
    super.initState();
    _initializePlayers();
  }
  
  void _initializePlayers() {
    // Initialize players for all camera slots
    for (int i = 0; i < maxCamerasPerPage; i++) {
      final player = Player();
      final controller = VideoController(player);
      
      _players.add(player);
      _controllers.add(controller);
      
      // Set up error listeners
      player.stream.error.listen((error) {
        if (mounted) {
          setState(() {
            _errorStates[i] = true;
          });
          print('Player $i error: $error');
        }
      });
      
      // Set up buffering listeners
      player.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() {
            _loadingStates[i] = buffering;
          });
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get available cameras from provider
    final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    final cameras = cameraProvider.cameras;
    
    // Get layout from provider if available
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
    if (layoutProvider.currentLayout != null) {
      _currentLayout = layoutProvider.currentLayout!;
      _gridColumns = _currentLayout.columns;
    }
    
    setState(() {
      _availableCameras = cameras;
      
      // Initialize slots with available cameras
      _loadCamerasForCurrentPage();
    });
    
    // Adjust grid columns based on screen size
    _updateGridColumnsBasedOnScreenSize();
  }
  
  // Update grid columns based on screen size
  void _updateGridColumnsBasedOnScreenSize() {
    final size = MediaQuery.of(context).size;
    
    if (size.width < 600) {
      // Mobile: 2 columns
      _gridColumns = 2;
    } else if (size.width < 900) {
      // Small tablet: 3 columns
      _gridColumns = 3;
    } else {
      // Use layout provider columns or default to 4
      _gridColumns = _currentLayout.columns;
    }
  }
  
  // Load cameras for the current page
  void _loadCamerasForCurrentPage() {
    // Clear all slots first
    for (int i = 0; i < maxCamerasPerPage; i++) {
      _selectedCameras[i] = null;
      
      // Stop any existing players
      if (_players.isNotEmpty && i < _players.length) {
        _players[i].stop();
      }
    }
    
    // Only load cameras if we have any
    if (_availableCameras.isNotEmpty) {
      int maxToLoad = math.min(maxCamerasPerPage, _availableCameras.length);
      
      for (int i = 0; i < maxToLoad; i++) {
        final camera = _availableCameras[i];
        _selectedCameras[i] = camera;
        
        // Start streaming if camera is connected
        if (camera.connected && _players.isNotEmpty && i < _players.length) {
          _streamCamera(i, camera);
        }
      }
    }
  }
  
  // Stream camera at a specific slot
  void _streamCamera(int slotIndex, Camera camera) {
    _errorStates[slotIndex] = false; // Reset error state
    
    if (slotIndex < _players.length) {
      final player = _players[slotIndex];
      
      // Check if camera has RTSP URL
      if (camera.rtspUri.isNotEmpty) {
        // Only open if player is not already playing something
        if (player.state.playlist.medias.isEmpty) {
          player.open(Media(camera.rtspUri));
        }
      } else {
        // Handle no URL available
        _errorStates[slotIndex] = true;
      }
    }
  }
  
  @override
  void dispose() {
    // Dispose all players
    for (final player in _players) {
      player.dispose();
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final cameraProvider = Provider.of<CameraDevicesProvider>(context);
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context);
    
    // Update layout if changed in provider
    if (layoutProvider.currentLayout != null && 
        layoutProvider.currentLayout!.id != _currentLayout.id) {
      _currentLayout = layoutProvider.currentLayout!;
      _gridColumns = _currentLayout.columns;
      _updateGridColumnsBasedOnScreenSize();
    }
    
    // Ensure cameras are loaded (defensive check)
    if (_availableCameras.isEmpty && cameraProvider.cameras.isNotEmpty) {
      _availableCameras = cameraProvider.cameras;
      _loadCamerasForCurrentPage();
    }
    
    // Fixed number of rows - 5 rows for standard layout
    const int fixedRows = 5;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Multi Camera View', style: theme.textTheme.headlineSmall),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                // Reload cameras
                _loadCamerasForCurrentPage();
              });
            },
          ),
        ],
      ),
      // Use Expanded to ensure the grid takes all available space
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              // Disable scrolling for fixed layout
              physics: const NeverScrollableScrollPhysics(),
              // No padding or spacing
              padding: EdgeInsets.zero,
              // Use GridDelegate with fixed cross axis count for predictable sizing
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridColumns,
                // Use aspect ratio that fills the space
                childAspectRatio: (size.width / _gridColumns) / (size.height / fixedRows),
                // No spacing between cells
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
              ),
              // Build camera cells
              itemCount: maxCamerasPerPage,
              itemBuilder: (context, index) {
                final camera = index < _selectedCameras.length ? _selectedCameras[index] : null;
                
                // If we have a camera and it's connected, show the video
                if (camera != null && camera.connected) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video player
                      ClipRect(
                        child: index < _controllers.length
                            ? MaterialVideoControlsTheme(
                                normal: MaterialVideoControlsThemeData(
                                  bottomButtonBar: const [
                                    MaterialPositionIndicator(),
                                  ],
                                  controlsHoverDuration: const Duration(seconds: 2),
                                ),
                                fullscreen: MaterialVideoControlsThemeData(
                                  bottomButtonBar: const [
                                    MaterialPositionIndicator(),
                                  ],
                                  controlsHoverDuration: const Duration(seconds: 2),
                                ),
                                child: Video(
                                  controller: _controllers[index],
                                  fill: Colors.black,
                                  controls: AdaptiveVideoControls,
                                ),
                              )
                            : const Center(child: Text('No player available')),
                      ),
                      
                      // Loading indicator
                      if (_loadingStates[index])
                        Center(
                          child: CircularProgressIndicator(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      
                      // Error indicator
                      if (_errorStates[index])
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 32),
                              const SizedBox(height: 8),
                              const Text(
                                'Stream Error',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      
                      // Camera name overlay (top left)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      
                      // Camera status overlay (bottom right)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: camera.recording
                                ? Colors.red.withOpacity(0.7)
                                : Colors.green.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            camera.recording ? 'REC' : 'LIVE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      
                      // Make the entire camera cell tappable
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // Navigate to single camera view
                            Navigator.pushNamed(
                              context,
                              '/live-view',
                              arguments: camera,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                } else {
                  // Show empty slot with darker background
                  return Container(
                    color: Colors.black38,
                    child: const Center(
                      child: Text(
                        'No Camera',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
"""

    # Write the fixed code to the file
    with open('lib/screens/multi_live_view_screen.dart', 'w') as f:
        f.write(fixed_code)
    
    print("Fixed multi live view screen code has been written to file.")

if __name__ == "__main__":
    fix_multiview_layout()