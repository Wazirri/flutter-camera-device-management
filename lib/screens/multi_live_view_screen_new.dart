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
  Map<int, Player> _players = {};
  Map<int, VideoController> _controllers = {};
  Map<int, bool> _loadingStates = {};
  Map<int, bool> _errorStates = {};
  
  int _currentLayoutCode = 303; // Default 4-camera layout
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get available cameras from provider
    final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
    final cameras = cameraProvider.cameras;
    
    setState(() {
      _availableCameras = cameras;
      _currentLayoutCode = layoutProvider.currentPageConfig.layoutCode;
    });
    
    // Initialize the players for the current layout
    _initializePlayersForCurrentLayout();
  }
  
  void _initializePlayersForCurrentLayout() {
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
    final currentLayout = layoutProvider.getLayoutByCode(_currentLayoutCode);
    
    if (currentLayout == null) return;
    
    // Create new players for each camera slot in the layout
    final maxCameras = currentLayout.maxCameraNumber;
    
    // Dispose of any existing players that are not needed in the new layout
    _disposeExtraPlayers(maxCameras);
    
    // Initialize players for all camera positions in this layout
    for (final position in currentLayout.cameraLoc) {
      final slotIndex = position.cameraCode - 1; // Convert to 0-based index
      
      // Only create a new player if one doesn't already exist for this slot
      if (!_players.containsKey(slotIndex)) {
        final player = Player();
        final controller = VideoController(player);
        
        _players[slotIndex] = player;
        _controllers[slotIndex] = controller;
        _loadingStates[slotIndex] = false;
        _errorStates[slotIndex] = false;
        
        // Set up error listeners
        player.stream.error.listen((error) {
          if (mounted) {
            setState(() {
              _errorStates[slotIndex] = true;
            });
            print('Player $slotIndex error: $error');
          }
        });
        
        // Set up buffering listeners
        player.stream.buffering.listen((buffering) {
          if (mounted) {
            setState(() {
              _loadingStates[slotIndex] = buffering;
            });
          }
        });
      }
    }
    
    // Update players with current camera assignments
    _updatePlayersWithCurrentAssignments();
  }
  
  void _disposeExtraPlayers(int maxNeeded) {
    final keysToRemove = _players.keys.where((key) => key >= maxNeeded).toList();
    
    for (final key in keysToRemove) {
      _players[key]?.dispose();
      _players.remove(key);
      _controllers.remove(key);
      _loadingStates.remove(key);
      _errorStates.remove(key);
    }
  }
  
  void _updatePlayersWithCurrentAssignments() {
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
    final currentConfig = layoutProvider.currentPageConfig;
    final cameraAssignments = currentConfig.cameraAssignments;
    
    // Stop all players first
    for (final player in _players.values) {
      player.stop();
    }
    
    // Start players with assigned cameras
    for (int i = 0; i < cameraAssignments.length; i++) {
      final cameraId = cameraAssignments[i];
      if (cameraId != null) {
        final camera = _findCameraById(cameraId);
        if (camera != null) {
          _playCamera(i, camera);
        }
      }
    }
  }
  
  Camera? _findCameraById(int cameraId) {
    try {
      return _availableCameras.firstWhere((camera) => camera.index == cameraId);
    } catch (e) {
      return null;
    }
  }
  
  void _playCamera(int slotIndex, Camera camera) {
    if (!_players.containsKey(slotIndex)) return;
    
    final player = _players[slotIndex]!;
    
    setState(() {
      _errorStates[slotIndex] = false;
      _loadingStates[slotIndex] = true;
    });
    
    // Start playing the camera
    try {
      player.open(Media(camera.rtspUri));
    } catch (e) {
      print('Error playing camera in slot $slotIndex: $e');
      setState(() {
        _errorStates[slotIndex] = true;
        _loadingStates[slotIndex] = false;
      });
    }
  }
  
  void _selectCameraForSlot(int slotIndex) {
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
    
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
                        'Slot ${slotIndex + 1} (Sayfa ${layoutProvider.currentPage + 1}) - Kamera Seç',
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
                      // Burada arama fonksiyonu eklenebilir
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    // Show all cameras - no page restrictions
                    itemCount: _availableCameras.length,
                    itemBuilder: (context, index) {
                      final camera = _availableCameras[index];
                      // Check if this camera is selected for this slot
                      final currentConfig = layoutProvider.currentPageConfig;
                      final isSelected = currentConfig.cameraAssignments.length > slotIndex && 
                                          currentConfig.cameraAssignments[slotIndex] == camera.index;
                      
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
                          // Update the camera assignment in the provider
                          layoutProvider.assignCameraToSlot(slotIndex, camera.index);
                          
                          // Play the camera
                          _playCamera(slotIndex, camera);
                          
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
                    // Clear the slot in the provider
                    layoutProvider.clearSlot(slotIndex);
                    
                    // Stop the player
                    if (_players.containsKey(slotIndex)) {
                      _players[slotIndex]!.stop();
                    }
                    
                    setState(() {
                      _errorStates[slotIndex] = false;
                      _loadingStates[slotIndex] = false;
                    });
                    
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
  
  void _showLayoutSelector() {
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Düzen Seçin'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.0,
                mainAxisSpacing: 8.0,
                crossAxisSpacing: 8.0,
              ),
              itemCount: layoutProvider.availableLayouts.length,
              itemBuilder: (context, index) {
                final layout = layoutProvider.availableLayouts[index];
                final isSelected = layoutProvider.currentPageConfig.layoutCode == layout.layoutCode;
                
                return InkWell(
                  onTap: () {
                    // Update the layout for the current page
                    layoutProvider.setCurrentPageLayout(layout.layoutCode);
                    
                    setState(() {
                      _currentLayoutCode = layout.layoutCode;
                    });
                    
                    // Initialize players for the new layout
                    _initializePlayersForCurrentLayout();
                    
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Stack(
                      children: [
                        // Layout preview
                        Positioned.fill(
                          child: CustomPaint(
                            painter: LayoutPreviewPainter(
                              layout.cameraLoc,
                              isSelected ? AppTheme.primaryColor : Colors.grey,
                            ),
                          ),
                        ),
                        // Layout code and camera count
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${layout.maxCameraNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    );
  }
  
  @override
  void dispose() {
    // Dispose all players
    for (final player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context);
    final size = MediaQuery.of(context).size;
    
    // Get the layout for the current page
    final currentLayout = layoutProvider.getLayoutByCode(layoutProvider.currentPageConfig.layoutCode);
    if (currentLayout == null) {
      return const Scaffold(
        body: Center(
          child: Text('Layout not found'),
        ),
      );
    }
    
    // Calculate available space for the layout
    final appBarHeight = AppBar().preferredSize.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final paginationControlsHeight = 60.0;
    
    final availableHeight = size.height - appBarHeight - paginationControlsHeight - bottomPadding - 16; // Account for padding
    final availableWidth = size.width;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi Camera View'),
        actions: [
          // Layout selector button
          IconButton(
            icon: const Icon(Icons.dashboard_customize),
            tooltip: 'Change layout',
            onPressed: _showLayoutSelector,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Camera layout area
          Expanded(
            child: Container(
              width: availableWidth,
              height: availableHeight,
              padding: const EdgeInsets.all(8.0),
              child: Stack(
                children: [
                  // Render each camera position based on the layout
                  for (final position in currentLayout.cameraLoc)
                    _buildCameraSlot(
                      position, 
                      availableWidth, 
                      availableHeight, 
                      layoutProvider,
                    ),
                ],
              ),
            ),
          ),
          
          // Pagination controls for pages
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: layoutProvider.currentPage > 0
                      ? () {
                          layoutProvider.setCurrentPage(layoutProvider.currentPage - 1);
                          _initializePlayersForCurrentLayout();
                        }
                      : null,
                ),
                
                // Page indicators (up to 10 pages)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < layoutProvider.maxPages; i++)
                      if (i == layoutProvider.currentPage)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor,
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      else
                        InkWell(
                          onTap: () {
                            layoutProvider.setCurrentPage(i);
                            _initializePlayersForCurrentLayout();
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.5),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
                
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: layoutProvider.currentPage < layoutProvider.maxPages - 1
                      ? () {
                          layoutProvider.setCurrentPage(layoutProvider.currentPage + 1);
                          _initializePlayersForCurrentLayout();
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
  
  Widget _buildCameraSlot(
    CameraPosition position, 
    double containerWidth, 
    double containerHeight,
    MultiViewLayoutProvider layoutProvider,
  ) {
    final slotIndex = position.cameraCode - 1; // Convert to 0-based index
    
    // Calculate pixel positions based on percentages
    final x1 = (position.x1 / 100) * containerWidth;
    final y1 = (position.y1 / 100) * containerHeight;
    final x2 = (position.x2 / 100) * containerWidth;
    final y2 = (position.y2 / 100) * containerHeight;
    
    // Get the camera assigned to this slot
    final cameraAssignments = layoutProvider.currentPageConfig.cameraAssignments;
    final cameraId = slotIndex < cameraAssignments.length ? cameraAssignments[slotIndex] : null;
    final camera = cameraId != null ? _findCameraById(cameraId) : null;
    
    final isLoading = _loadingStates[slotIndex] ?? false;
    final hasError = _errorStates[slotIndex] ?? false;
    
    return Positioned(
      left: x1,
      top: y1,
      width: x2 - x1,
      height: y2 - y1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selectCameraForSlot(slotIndex),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera slot content
              if (camera == null)
                // Empty slot
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add Camera',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              else if (hasError)
                // Error state
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Stream Error',
                        style: TextStyle(
                          color: Colors.red[300],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Retry'),
                        onPressed: () => _playCamera(slotIndex, camera),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(80, 28),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_controllers.containsKey(slotIndex))
                // Video player
                Video(
                  controller: _controllers[slotIndex]!,
                  controls: null, // Simple controls or none for grid view
                ),
              
              // Loading indicator
              if (isLoading && camera != null && !hasError)
                const Center(
                  child: CircularProgressIndicator(),
                ),
              
              // Camera name overlay at the top
              if (camera != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    color: Colors.black.withOpacity(0.7),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            camera.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          camera.connected ? Icons.link : Icons.link_off,
                          size: 14,
                          color: camera.connected ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
                
              // Change camera button at the bottom
              if (camera != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      icon: const Icon(Icons.sync),
                      color: Colors.white,
                      tooltip: 'Change camera',
                      onPressed: () => _selectCameraForSlot(slotIndex),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class LayoutPreviewPainter extends CustomPainter {
  final List<CameraPosition> positions;
  final Color color;
  
  LayoutPreviewPainter(this.positions, this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // Draw rectangles for each camera position
    for (final position in positions) {
      final rect = Rect.fromLTRB(
        (position.x1 / 100) * size.width,
        (position.y1 / 100) * size.height,
        (position.x2 / 100) * size.width,
        (position.y2 / 100) * size.height,
      );
      
      canvas.drawRect(rect, paint);
    }
  }
  
  @override
  bool shouldRepaint(LayoutPreviewPainter oldDelegate) => 
    positions != oldDelegate.positions || color != oldDelegate.color;
}