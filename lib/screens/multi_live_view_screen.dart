import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../models/camera.dart';
import '../providers/camera_devices_provider.dart';
import '../providers/multi_view_layout_provider.dart';
import '../utils/responsive_helper.dart';
import '../widgets/desktop_side_menu.dart';
import '../widgets/mobile_bottom_navigation_bar.dart';
import '../widgets/mobile_menu.dart';
import '../widgets/video_controls_new.dart';

class MultiLiveViewScreen extends StatefulWidget {
  static const String routeName = '/multi-live-view';

  const MultiLiveViewScreen({Key? key}) : super(key: key);

  @override
  State<MultiLiveViewScreen> createState() => _MultiLiveViewScreenState();
}

class _MultiLiveViewScreenState extends State<MultiLiveViewScreen> {
  final List<Player> _players = [];
  final List<VideoController> _controllers = [];
  List<Camera?> _allCameras = [];
  List<Camera?> _selectedCameras = [];
  List<int?> _cameraIndexes = []; // Store original indexes
  int _currentLayout = 4; // Default layout showing 4 cameras
  int _gridColumns = 2; // Initial column count
  int _currentPage = 0;
  int _totalPages = 1;
  int _camerasPerPage = 4;

  late ScrollController _scrollController;
  bool _showControls = false;
  int? _activePlayerIndex;
  Timer? _controlsTimer;

  // Track camera-to-player assignments
  Map<int, int> _cameraSlotMap = {}; // Maps camera index to grid slot
  Map<int, int> _slotCameraMap = {}; // Maps grid slot to camera index
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCameras();
    });
  }

  void _initCameras() {
    final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
    
    // Load all available cameras from the provider
    _allCameras = cameraProvider.cameras;
    
    // Load the layout configuration
    _initializeLayoutConfiguration(layoutProvider);
    
    // Update camera selections based on the current configuration
    _updateCameraSelections();
  }
  
  void _initializeLayoutConfiguration(MultiViewLayoutProvider layoutProvider) {
    // Get the current layout configuration or initialize with defaults
    final layoutConfig = layoutProvider.getCurrentLayoutConfig();
    
    setState(() {
      _currentLayout = layoutConfig.slotsCount; // Number of camera slots in the layout
      _gridColumns = layoutConfig.columns; // Number of columns in the grid
      _camerasPerPage = _currentLayout; // Number of cameras to show per page
    
      // Initialize the mapping between cameras and slots
      _cameraSlotMap = layoutProvider.cameraSlotMap;
      _slotCameraMap = layoutProvider.slotCameraMap;
    });
    
    // Create and initialize players for each slot in the layout
    _initializePlayers();
  }
  
  void _initializePlayers() {
    // Clear existing players and controllers
    for (final player in _players) {
      player.dispose();
    }
    _players.clear();
    _controllers.clear();
    
    // Create new players for the current layout
    for (int i = 0; i < _currentLayout; i++) {
      final player = Player();
      final controller = VideoController(player);
      
      _players.add(player);
      _controllers.add(controller);
    }
  }
  
  void _updateCameraSelections() {
    // This updates the cameras shown in the grid based on:
    // 1. The current page
    // 2. The camera slot mapping
    // 3. Available cameras from the provider
    
    setState(() {
      _selectedCameras = List.filled(_currentLayout, null);
      _cameraIndexes = List.filled(_currentLayout, null);
      
      // For each slot in the current layout
      for (int slotIndex = 0; slotIndex < _currentLayout; slotIndex++) {
        // Check if there's a camera assigned to this slot via the mapping
        if (_slotCameraMap.containsKey(slotIndex)) {
          final cameraIndex = _slotCameraMap[slotIndex];
          if (cameraIndex != null && cameraIndex < _allCameras.length) {
            _selectedCameras[slotIndex] = _allCameras[cameraIndex];
            _cameraIndexes[slotIndex] = cameraIndex;
          }
        }
      }
      
      // Calculate total pages (not used now but might be needed for pagination)
      _totalPages = (_allCameras.length / _camerasPerPage).ceil();
    });
    
    // Start streaming for the cameras in the current view
    _startStreaming();
  }
  
  void _startStreaming() {
    // Start streaming for all cameras in the current view
    for (int i = 0; i < _selectedCameras.length; i++) {
      final camera = _selectedCameras[i];
      final player = i < _players.length ? _players[i] : null;
      
      if (camera != null && player != null) {
        // Get the appropriate URI based on platform and preferences
        String streamUri = '';
        
        // Use the appropriate URI based on what's available
        // Preference order: subUri (for live streaming) > mediaUri > others
        if (camera.subUri != null && camera.subUri!.isNotEmpty) {
          streamUri = camera.subUri!;
        } else if (camera.mediaUri != null && camera.mediaUri!.isNotEmpty) {
          streamUri = camera.mediaUri!;
        } else if (camera.remoteUri != null && camera.remoteUri!.isNotEmpty) {
          streamUri = camera.remoteUri!;
        }
        
        if (streamUri.isNotEmpty) {
          Map<String, dynamic> extraParams = {};
          
          // Add authentication if credentials are available
          if (camera.username != null && camera.username!.isNotEmpty &&
              camera.password != null && camera.password!.isNotEmpty) {
            // For RTSP URLs, embed credentials in the URL format rtsp://username:password@host:port/...
            final rtspRegex = RegExp(r'^rtsp://');
            if (rtspRegex.hasMatch(streamUri)) {
              final uri = Uri.parse(streamUri);
              final authority = uri.authority;
              
              // Check if the URL already has credentials
              if (!authority.contains('@')) {
                final uriWithAuth = streamUri.replaceFirst(
                  'rtsp://$authority', 
                  'rtsp://${camera.username}:${camera.password}@$authority'
                );
                streamUri = uriWithAuth;
              }
            } else {
              // For other protocols, use the credentials parameter
              extraParams = {
                'user-agent': 'Flutter MediaKit Player',
                'username': camera.username,
                'password': camera.password,
              };
            }
          }
          
          // Configure and start streaming
          player.open(
            Media(
              streamUri,
              httpHeaders: {},
              extras: extraParams,
            ),
            play: true,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _scrollController.dispose();
    for (final player in _players) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final size = MediaQuery.of(context).size;
    
    // Calculate available height for the grid
    final appBarHeight = AppBar().preferredSize.height;
    final paginationControlsHeight = _totalPages > 1 ? 60.0 : 0.0;
    final bottomNavHeight = ResponsiveHelper.isMobile(context) ? 56.0 : 0.0;
    
    // Calculate available height for the grid
    final availableHeight = size.height - appBarHeight - paginationControlsHeight - bottomNavHeight;
    
    // Filter out null cameras and create a list of only active cameras
    final activeCameras = _selectedCameras.where((cam) => cam != null).toList();
    final activeCameraCount = activeCameras.length;
    
    // Calculate how many actual rows we need for the active cameras
    // This ensures we don't reserve space for empty slots
    final activeRowsNeeded = (activeCameraCount / _gridColumns).ceil();
    
    // Calculate optimal aspect ratio based on the available height and active rows
    final double cellWidth = size.width / _gridColumns;
    final double cellHeight = availableHeight / activeRowsNeeded;
    final double aspectRatio = cellWidth / cellHeight;

    return Scaffold(
      drawer: ResponsiveHelper.isMobile(context) ? const MobileMenu() : null,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Kamera Canlı İzleme'),
            const Spacer(),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    // Show layout settings dialog
                    _showLayoutSettingsDialog();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisAlignment: MainAxisAlignment.start, 
        children: [
          // Fixed-height grid view of cameras (non-scrollable)
          SizedBox(
            height: availableHeight,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(), // Disable scrolling to fit all slots
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridColumns,
                childAspectRatio: aspectRatio, // Custom aspect ratio to fit all slots perfectly
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
              ),
              itemCount: _selectedCameras.length,
              itemBuilder: (context, index) {
                final camera = _selectedCameras[index];
                final originalIndex = _cameraIndexes[index];
                
                if (camera == null) {
                  // Empty slot - show placeholder with plus icon for adding camera
                  return GestureDetector(
                    onTap: () {
                      _showCameraSelectionDialog(index);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        border: Border.all(color: Colors.grey[800]!, width: 1),
                      ),
                      child: const Center(
                        child: Icon(Icons.add_circle_outline, size: 48, color: Colors.grey),
                      ),
                    ),
                  );
                }
                
                // Use original index to get the right camera info
                // This prevents issues when reordering cameras
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _activePlayerIndex = index;
                      _showControls = true;
                      _resetControlsTimer();
                    });
                  },
                  child: Stack(
                    children: [
                      // Video player
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _activePlayerIndex == index 
                              ? Theme.of(context).primaryColor 
                              : Colors.grey[900]!,
                            width: _activePlayerIndex == index ? 2 : 1,
                          ),
                        ),
                        child: index < _controllers.length 
                          ? Video(controller: _controllers[index])
                          : const Center(child: CircularProgressIndicator()),
                      ),
                      
                      // Camera name overlay
                      Positioned(
                        top: 5,
                        left: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            camera.name ?? 'Camera ${originalIndex ?? index}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      
                      // Controls overlay (only shown for active player)
                      if (_showControls && _activePlayerIndex == index)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Top row with camera info and close button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          camera.name ?? 'Camera ${originalIndex ?? index}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          _showControls = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                
                                // Bottom row with controls
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      // Full screen button
                                      IconButton(
                                        icon: const Icon(Icons.fullscreen, color: Colors.white),
                                        onPressed: () {
                                          _openFullScreenView(camera, originalIndex ?? index);
                                        },
                                      ),
                                      // Remove camera button
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                                        onPressed: () {
                                          _removeCameraFromSlot(index);
                                        },
                                      ),
                                      // Change camera button
                                      IconButton(
                                        icon: const Icon(Icons.swap_horiz, color: Colors.white),
                                        onPressed: () {
                                          _showCameraSelectionDialog(index);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Bottom pagination controls (if we have multiple pages)
          if (_totalPages > 1)
            Container(
              height: paginationControlsHeight,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              color: Colors.grey[900],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: _currentPage > 0 
                      ? () {
                          setState(() {
                            _currentPage--;
                            _updateCameraSelections();
                          });
                        }
                      : null,
                  ),
                  Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _currentPage < _totalPages - 1 
                      ? () {
                          setState(() {
                            _currentPage++;
                            _updateCameraSelections();
                          });
                        }
                      : null,
                  ),
                ],
              ),
            ),
        ],
      ),
      // Mobile bottom navigation
      bottomNavigationBar: ResponsiveHelper.isMobile(context)
        ? const MobileBottomNavigationBar(currentIndex: 1)
        : null,
      // Desktop side menu
      endDrawer: isDesktop ? const DesktopSideMenu() : null,
    );
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _openFullScreenView(Camera camera, int cameraIndex) {
    // Navigate to single camera view with the selected camera
    Navigator.pushNamed(
      context,
      '/live-view',
      arguments: {'camera': camera, 'index': cameraIndex},
    );
  }

  void _removeCameraFromSlot(int slotIndex) {
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
    
    // Update our internal state
    setState(() {
      _selectedCameras[slotIndex] = null;
      _cameraIndexes[slotIndex] = null;
      
      // Update the mappings
      final originalCameraIndex = _slotCameraMap[slotIndex];
      if (originalCameraIndex != null) {
        _cameraSlotMap.remove(originalCameraIndex);
      }
      _slotCameraMap.remove(slotIndex);
    });
    
    // Stop the player for this slot
    if (slotIndex < _players.length) {
      _players[slotIndex].stop();
    }
    
    // Update the provider's state
    layoutProvider.updateCameraSlotMapping(_cameraSlotMap, _slotCameraMap);
  }

  void _showCameraSelectionDialog(int slotIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kamera Seçin'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _allCameras.length,
              itemBuilder: (context, index) {
                final camera = _allCameras[index];
                if (camera == null) return const SizedBox.shrink();
                
                return ListTile(
                  title: Text(camera.name ?? 'Camera $index'),
                  subtitle: Text(camera.cameraIp ?? 'Unknown IP'),
                  onTap: () {
                    _assignCameraToSlot(index, slotIndex);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _assignCameraToSlot(int cameraIndex, int slotIndex) {
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
    
    // Check if this camera is already assigned to another slot
    int? existingSlot;
    _cameraSlotMap.forEach((camIdx, slot) {
      if (camIdx == cameraIndex) {
        existingSlot = slot;
      }
    });
    
    // If the camera is already assigned to another slot, remove it from there
    if (existingSlot != null) {
      setState(() {
        _selectedCameras[existingSlot!] = null;
        _cameraIndexes[existingSlot!] = null;
        _slotCameraMap.remove(existingSlot);
      });
      
      // Stop the player for the previous slot
      if (existingSlot! < _players.length) {
        _players[existingSlot!].stop();
      }
    }
    
    // If there's already a camera in this slot, clear it
    final existingCamera = _slotCameraMap[slotIndex];
    if (existingCamera != null) {
      _cameraSlotMap.remove(existingCamera);
    }
    
    // Assign the new camera to this slot
    setState(() {
      _selectedCameras[slotIndex] = _allCameras[cameraIndex];
      _cameraIndexes[slotIndex] = cameraIndex;
      
      // Update the mappings
      _cameraSlotMap[cameraIndex] = slotIndex;
      _slotCameraMap[slotIndex] = cameraIndex;
    });
    
    // Start streaming for this camera
    if (slotIndex < _players.length) {
      final camera = _allCameras[cameraIndex];
      if (camera != null) {
        final player = _players[slotIndex];
        
        // Same streaming logic as in _startStreaming method
        String streamUri = '';
        
        if (camera.subUri != null && camera.subUri!.isNotEmpty) {
          streamUri = camera.subUri!;
        } else if (camera.mediaUri != null && camera.mediaUri!.isNotEmpty) {
          streamUri = camera.mediaUri!;
        } else if (camera.remoteUri != null && camera.remoteUri!.isNotEmpty) {
          streamUri = camera.remoteUri!;
        }
        
        if (streamUri.isNotEmpty) {
          Map<String, dynamic> extraParams = {};
          
          if (camera.username != null && camera.username!.isNotEmpty &&
              camera.password != null && camera.password!.isNotEmpty) {
            final rtspRegex = RegExp(r'^rtsp://');
            if (rtspRegex.hasMatch(streamUri)) {
              final uri = Uri.parse(streamUri);
              final authority = uri.authority;
              
              if (!authority.contains('@')) {
                final uriWithAuth = streamUri.replaceFirst(
                  'rtsp://$authority', 
                  'rtsp://${camera.username}:${camera.password}@$authority'
                );
                streamUri = uriWithAuth;
              }
            } else {
              extraParams = {
                'user-agent': 'Flutter MediaKit Player',
                'username': camera.username,
                'password': camera.password,
              };
            }
          }
          
          player.open(
            Media(
              streamUri,
              httpHeaders: {},
              extras: extraParams,
            ),
            play: true,
          );
        }
      }
    }
    
    // Update the provider's state
    layoutProvider.updateCameraSlotMapping(_cameraSlotMap, _slotCameraMap);
  }

  void _showLayoutSettingsDialog() {
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
    final layouts = layoutProvider.getAvailableLayouts();
    
    int tempSelectedLayout = _currentLayout;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Kamera Düzeni Ayarları'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Kamera Sayısı ve Düzen Seçimi:'),
                  const SizedBox(height: 10),
                  
                  // Layout selection grid
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: layouts.map((layout) {
                      final isSelected = tempSelectedLayout == layout.slotsCount;
                      
                      return InkWell(
                        onTap: () {
                          setState(() {
                            tempSelectedLayout = layout.slotsCount;
                          });
                        },
                        child: Container(
                          width: 80,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected 
                                ? Theme.of(context).primaryColor 
                                : Colors.grey,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${layout.slotsCount}',
                                style: TextStyle(
                                  fontWeight: isSelected 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                                  color: isSelected 
                                    ? Theme.of(context).primaryColor 
                                    : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${layout.columns}x${layout.rows}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected 
                                    ? Theme.of(context).primaryColor 
                                    : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('İptal'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Uygula'),
                  onPressed: () {
                    // Apply the new layout
                    if (tempSelectedLayout != _currentLayout) {
                      layoutProvider.changeLayout(tempSelectedLayout);
                      
                      // Reinitialize everything with the new layout
                      _initializeLayoutConfiguration(layoutProvider);
                      _updateCameraSelections();
                    }
                    
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
