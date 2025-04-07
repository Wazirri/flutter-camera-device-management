import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/camera_devices_provider.dart';
import '../providers/multi_view_layout_provider.dart';
import '../models/camera_device.dart';
import '../models/camera_layout.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';
import '../utils/responsive_helper.dart';
import 'dart:math' as math;

class MultiLiveViewScreenNew extends StatefulWidget {
  const MultiLiveViewScreenNew({Key? key}) : super(key: key);

  @override
  State<MultiLiveViewScreenNew> createState() => _MultiLiveViewScreenNewState();
}

class _MultiLiveViewScreenNewState extends State<MultiLiveViewScreenNew> {
  // State variables
  List<Camera> _availableCameras = [];
  late MultiViewLayoutProvider _layoutProvider;
  late List<Player> _players;
  late List<VideoController> _controllers;
  late List<bool> _loadingStates;
  late List<bool> _errorStates;
  late Size _viewportSize;
  
  @override
  void initState() {
    super.initState();
    _layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
    
    // Initialize players, controllers, and state arrays
    _initializeArrays();
  }
  
  void _initializeArrays() {
    final maxCamerasPerPage = _layoutProvider.maxCamerasPerPage;
    
    // Initialize players for all camera slots
    _players = List.generate(maxCamerasPerPage, (_) => Player());
    _controllers = List.generate(maxCamerasPerPage, (i) => VideoController(_players[i]));
    _loadingStates = List.filled(maxCamerasPerPage, false);
    _errorStates = List.filled(maxCamerasPerPage, false);
    
    // Add listeners to players
    for (int i = 0; i < maxCamerasPerPage; i++) {
      final player = _players[i];
      
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
    
    // Get the viewport size
    _viewportSize = MediaQuery.of(context).size;
    
    // Get available cameras from provider
    final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    _availableCameras = cameraProvider.cameras;
    
    // Update camera streams based on layout provider assignments
    _updateCameraStreams();
  }
  
  // Update all camera streams based on current layout assignments
  void _updateCameraStreams() {
    final currentPage = _layoutProvider.currentPage;
    final assignments = _layoutProvider.getCurrentPageAssignments();
    
    // Stop all players first
    for (final player in _players) {
      player.stop();
    }
    
    // Clear all states
    setState(() {
      _loadingStates = List.filled(_layoutProvider.maxCamerasPerPage, false);
      _errorStates = List.filled(_layoutProvider.maxCamerasPerPage, false);
    });
    
    // Start players for assigned cameras
    for (final assignment in assignments) {
      if (assignment.page == currentPage && assignment.cameraId != null) {
        final slot = assignment.slot;
        
        // Find the camera by ID
        final camera = _availableCameras.firstWhere(
          (camera) => camera.id == assignment.cameraId,
          orElse: () => null as Camera,
        );
        
        if (camera != null) {
          _startPlayerForCamera(slot, camera);
        }
      }
    }
  }
  
  // Start a player for a specific camera
  void _startPlayerForCamera(int slot, Camera camera) {
    if (slot >= 0 && slot < _players.length) {
      setState(() {
        _loadingStates[slot] = true;
        _errorStates[slot] = false;
      });
      
      try {
        _players[slot].open(Media(camera.rtspUri));
      } catch (e) {
        print('Error playing camera $slot: $e');
        setState(() {
          _errorStates[slot] = true;
          _loadingStates[slot] = false;
        });
      }
    }
  }
  
  // Handle selecting a camera for a slot
  void _selectCameraForSlot(int slot, Camera camera) {
    // Assign the camera to this slot in the layout provider
    _layoutProvider.assignCameraToSlot(slot, camera.id);
    
    // Start the player for this camera
    _startPlayerForCamera(slot, camera);
  }
  
  // Clear a slot
  void _clearSlot(int slot) {
    // Stop the player
    if (slot >= 0 && slot < _players.length) {
      _players[slot].stop();
      
      setState(() {
        _loadingStates[slot] = false;
        _errorStates[slot] = false;
      });
      
      // Remove the camera assignment from the layout
      _layoutProvider.clearSlot(slot);
    }
  }
  
  // Show camera selector for a slot
  void _showCameraSelector(int slot) {
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
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Slot ${slot + 1} (Sayfa ${_layoutProvider.currentPage + 1}) - Kamera Seç',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Search field for cameras
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Kamera ara...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) {
                      // Search functionality could be added here
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _availableCameras.length,
                    itemBuilder: (context, index) {
                      final camera = _availableCameras[index];
                      
                      // Check if this camera is selected for this slot
                      final currentCameraId = _layoutProvider.getCameraIdForSlot(slot);
                      final isSelected = currentCameraId == camera.id;
                      
                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: camera.mainSnapShot.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  camera.mainSnapShot,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.broken_image_outlined,
                                      size: 24.0,
                                      color: Colors.white54,
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.videocam_off,
                                size: 24.0,
                                color: Colors.white54,
                              ),
                        ),
                        title: Text(camera.name),
                        subtitle: Text(
                          camera.connected
                              ? 'Bağlı (${camera.ip})'
                              : 'Bağlantı yok (${camera.ip})',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            camera.connected
                                ? const Icon(Icons.link, color: Colors.green)
                                : const Icon(Icons.link_off, color: Colors.red),
                            if (isSelected)
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Icon(Icons.check_circle, color: Colors.green),
                              )
                          ],
                        ),
                        selected: isSelected,
                        onTap: () {
                          _selectCameraForSlot(slot, camera);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
                // Option to clear the slot
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Bu slotu temizle'),
                  onTap: () {
                    _clearSlot(slot);
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
  
  // Change the current page
  void _changePage(int page) {
    if (page >= 0 && page < _layoutProvider.totalPages) {
      _layoutProvider.changePage(page);
      
      // Update camera streams for the new page
      _updateCameraStreams();
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
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context);
    final cameraProvider = Provider.of<CameraDevicesProvider>(context);
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final size = MediaQuery.of(context).size;
    
    // Get current page and total pages from the layout provider
    final currentPage = layoutProvider.currentPage;
    final totalPages = layoutProvider.totalPages;
    
    // Calculate the optimal grid columns based on screen size
    final gridColumns = layoutProvider.calculateOptimalGridColumns(context, size);
    
    // Calculate available height for the grid
    final appBarHeight = AppBar().preferredSize.height;
    final paginationControlsHeight = totalPages > 1 ? 60.0 : 0.0;
    final bottomNavHeight = 56.0;
    
    // Calculate available height for the grid
    final availableHeight = size.height - appBarHeight - paginationControlsHeight - bottomNavHeight;
    
    // Calculate number of rows needed
    final rowCount = (layoutProvider.maxCamerasPerPage / gridColumns).ceil();
    
    // Calculate the cell height to ensure no vertical scrolling is needed
    final gridHeight = availableHeight - 16; // Account for padding
    final cellHeight = (gridHeight / rowCount) - 8; // Account for grid spacing
    
    // Calculate the cell width based on the 16:9 aspect ratio
    final cellWidth = cellHeight * 16 / 9;
    
    return Consumer<MultiViewLayoutProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Multi Camera View (${currentPage + 1}/${totalPages})'),
            actions: [
              // Grid layout selector
              PopupMenuButton<int>(
                tooltip: 'Change grid layout',
                icon: const Icon(Icons.grid_view),
                onSelected: (columns) {
                  provider.setGridColumns(columns);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 2,
                    child: Text('2 columns'),
                  ),
                  const PopupMenuItem(
                    value: 3,
                    child: Text('3 columns'),
                  ),
                  const PopupMenuItem(
                    value: 4,
                    child: Text('4 columns'),
                  ),
                  const PopupMenuItem(
                    value: 5,
                    child: Text('5 columns'),
                  ),
                  const PopupMenuItem(
                    value: 6,
                    child: Text('6 columns'),
                  ),
                ],
              ),
              
              // Clear all button
              IconButton(
                icon: const Icon(Icons.clear_all),
                tooltip: 'Clear all cameras on this page',
                onPressed: () {
                  provider.clearCurrentPage();
                  
                  // Stop all players
                  for (final player in _players) {
                    player.stop();
                  }
                  
                  setState(() {
                    _loadingStates = List.filled(layoutProvider.maxCamerasPerPage, false);
                    _errorStates = List.filled(layoutProvider.maxCamerasPerPage, false);
                  });
                },
              ),
              
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Fixed-height grid view of cameras (non-scrollable)
              // Ensures all players fit within the screen with proper aspect ratio
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  physics: const NeverScrollableScrollPhysics(), // Prevent scrolling
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridColumns,
                    childAspectRatio: 16 / 9, // Maintain 16:9 aspect ratio
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: layoutProvider.maxCamerasPerPage,
                  itemBuilder: (context, index) {
                    // Get camera ID for this slot
                    final cameraId = provider.getCameraIdForSlot(index);
                    
                    // Find camera object if there's an ID assigned
                    Camera? camera;
                    if (cameraId != null) {
                      camera = _availableCameras.firstWhere(
                        (c) => c.id == cameraId,
                        orElse: () => null as Camera,
                      );
                    }
                    
                    final isLoading = _loadingStates[index];
                    final hasError = _errorStates[index];
                    
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _showCameraSelector(index),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Empty slot background
                            if (camera == null)
                              Container(
                                color: Colors.black45,
                                child: Center(
                                  child: Icon(
                                    Icons.videocam_off,
                                    size: 48,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            
                            // Video player if camera is assigned
                            if (camera != null)
                              AbsorbPointer(
                                absorbing: false, // Allow interaction with player
                                child: Video(
                                  controller: _controllers[index],
                                  controls: NoVideoControls,
                                  fill: Colors.black,
                                ),
                              ),
                            
                            // Loading indicator
                            if (isLoading && camera != null)
                              Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.accentColor.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            
                            // Error indicator
                            if (hasError && camera != null)
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade300,
                                      size: 36,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Video akışı yüklenemedi',
                                      style: TextStyle(
                                        color: Colors.red.shade300,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            // Controls overlay (always visible on top)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Row(
                                children: [
                                  // Fullscreen button
                                  if (camera != null)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.fullscreen,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        if (camera != null) {
                                          Navigator.pushNamed(
                                            context,
                                            '/live-view',
                                            arguments: {'camera': camera},
                                          );
                                        }
                                      },
                                    ),
                                  
                                  // Remove camera button
                                  if (camera != null)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        color: Colors.white,
                                      ),
                                      onPressed: () => _clearSlot(index),
                                    ),
                                ],
                              ),
                            ),
                            
                            // Camera name and status
                            if (camera != null)
                              Positioned(
                                left: 8,
                                bottom: 8,
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
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            
                            // Slot number indicator
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Pagination controls - only show if we have multiple pages
              if (totalPages > 1)
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // First page button
                      IconButton(
                        icon: const Icon(Icons.first_page),
                        onPressed: currentPage > 0 ? () => _changePage(0) : null,
                      ),
                      // Previous page button
                      IconButton(
                        icon: const Icon(Icons.navigate_before),
                        onPressed: currentPage > 0 ? () => _changePage(currentPage - 1) : null,
                      ),
                      
                      // Page indicators
                      for (int i = 0; i < totalPages; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: i == currentPage
                                  ? AppTheme.primaryColor
                                  : AppTheme.secondaryColor,
                              minimumSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () => _changePage(i),
                            child: Text('${i + 1}'),
                          ),
                        ),
                      
                      // Next page button
                      IconButton(
                        icon: const Icon(Icons.navigate_next),
                        onPressed: currentPage < totalPages - 1
                            ? () => _changePage(currentPage + 1)
                            : null,
                      ),
                      // Last page button
                      IconButton(
                        icon: const Icon(Icons.last_page),
                        onPressed: currentPage < totalPages - 1
                            ? () => _changePage(totalPages - 1)
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}