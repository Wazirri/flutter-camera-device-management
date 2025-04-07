import 'package:flutter/material.dart';
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
  // Maximum number of cameras per page (requirement: 20 per page)
  static const int maxCamerasPerPage = 20;
  
  // State variables
  List<Camera> _availableCameras = [];
  final List<Camera?> _selectedCameras = List.filled(maxCamerasPerPage, null);
  final List<Player> _players = [];
  final List<VideoController> _controllers = [];
  final List<bool> _loadingStates = List.filled(maxCamerasPerPage, false);
  final List<bool> _errorStates = List.filled(maxCamerasPerPage, false);
  int _currentPage = 0;
  int _totalPages = 1;
  int _gridColumns = 4; // Default grid columns for desktop
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
      _totalPages = (cameras.length / maxCamerasPerPage).ceil();
      if (_totalPages == 0) _totalPages = 1; // Always have at least one page
      
      // Initialize slots with available cameras for the current page
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
    
    // Calculate start and end indexes for the current page
    int startIndex = _currentPage * maxCamerasPerPage;
    int endIndex = math.min(startIndex + maxCamerasPerPage, _availableCameras.length);
    
    // Only load cameras if we have any
    if (_availableCameras.isNotEmpty) {
      for (int i = startIndex, slotIndex = 0; i < endIndex; i++, slotIndex++) {
        final camera = _availableCameras[i];
        _selectedCameras[slotIndex] = camera;
        
        // Start streaming if camera is connected
        if (camera.connected && _players.isNotEmpty && slotIndex < _players.length) {
          _streamCamera(slotIndex, camera);
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
        // Only open if not already playing something
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
      _updateGridColumnsBasedOnScreenSize(); // Recalculate grid dimensions
    }
    
    // Ensure cameras are loaded (defensive check)
    if (_availableCameras.isEmpty && cameraProvider.cameras.isNotEmpty) {
      _availableCameras = cameraProvider.cameras;
      _loadCamerasForCurrentPage();
    }
    
    // Calculate the height available for the grid
    final appBarHeight = AppBar().preferredSize.height;
    final bottomNavHeight = ResponsiveHelper.isMobile(context) ? 56.0 : 0.0;
    final paginationControlsHeight = 48.0; // Reduced height for pagination controls
    final availableHeight = size.height - appBarHeight - bottomNavHeight;
    
    // Filter out null cameras for the grid
    final List<Camera> activeCameras = _selectedCameras.whereType<Camera>().toList();
    final activeCameraCount = activeCameras.length;
    
    // Calculate how many rows we need based on camera count
    final int activeRowsNeeded = math.max(1, math.min(5, (activeCameraCount + _gridColumns - 1) ~/ _gridColumns)); 
    
    // Calculate optimal aspect ratio based on the available height and active rows
    final double cellWidth = size.width / _gridColumns;
    // Adjust the available height by removing the pagination controls height if needed
    final double cellHeight = (availableHeight - (_totalPages > 1 ? paginationControlsHeight : 0)) / activeRowsNeeded - 0.1;
    final double aspectRatio = cellWidth / cellHeight;
    
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
      body: Column(
        children: [
          // Main grid view that takes up most of the space
          Expanded(
            child: GridView.builder(
              // Disable scrolling as we're handling paging ourselves
              physics: const NeverScrollableScrollPhysics(),
              // Grid properties
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridColumns,
                childAspectRatio: aspectRatio,
                // Remove all spacing between grid cells for maximum screen utilization
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
              ),
              // Use zero padding to maximize viewable area
              padding: EdgeInsets.zero,
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
                            color: theme.colorScheme.secondary, // Use accent color
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
          
          // Pagination controls (only shown if we have multiple pages)
          if (_totalPages > 1)
            Container(
              height: paginationControlsHeight,
              color: theme.colorScheme.surface.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() {
                              _currentPage--;
                              _loadCamerasForCurrentPage();
                            });
                          }
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _currentPage < _totalPages - 1
                        ? () {
                            setState(() {
                              _currentPage++;
                              _loadCamerasForCurrentPage();
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
