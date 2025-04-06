import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';
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
  
  // Method to update grid columns based on screen size
  void _updateGridColumnsBasedOnScreenSize() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate available height for the grid
    final appBarHeight = AppBar().preferredSize.height;
    final bottomNavHeight = ResponsiveHelper.isMobile(context) ? 56.0 : 0.0; // Only for mobile
    final paginationControlsHeight = 60.0; // Estimated height for pagination controls
    
    // Calculate available height for the grid (excluding app bar, pagination controls, and bottom nav)
    final availableHeight = screenHeight - appBarHeight - (_totalPages > 1 ? paginationControlsHeight : 0) - bottomNavHeight - 32; // Add extra padding
    
    // First, determine max possible columns based on screen width
    int maxColumns;
    if (screenWidth > 1400) {
      maxColumns = 5;
    } else if (screenWidth > 1100) {
      maxColumns = 4;
    } else if (screenWidth > 800) {
      maxColumns = 3;
    } else if (screenWidth > 500) {
      maxColumns = 2;
    } else {
      maxColumns = 1;
    }
    
    // Start with max columns and adjust down if needed to fit height
    _gridColumns = maxColumns;
    
    // Iteratively check if all cameras fit within the available height
    bool fitsInHeight = false;
    while (!fitsInHeight && _gridColumns > 1) {
      // Calculate the number of rows needed for current column count
      final rowsNeeded = (maxCamerasPerPage / _gridColumns).ceil();
      
      // Calculate cell dimensions based on 16:9 aspect ratio
      final cellWidth = (screenWidth - 32) / _gridColumns; // Account for padding
      final cellHeight = cellWidth * 9 / 16; // 16:9 aspect ratio
      
      // Calculate total grid height including spacing between rows
      final totalGridHeight = cellHeight * rowsNeeded + (rowsNeeded - 1) * 8;
      
      if (totalGridHeight <= availableHeight) {
        fitsInHeight = true;
      } else {
        // Reduce columns if it doesn't fit
        _gridColumns -= 1;
      }
    }
  }
  
  // Method to load cameras for the current page
  // We now only initialize empty slots, not override existing ones
  void _loadCamerasForCurrentPage() {
    // For initial page load only
    // No longer clears the slots automatically
    if (_currentPage == 0 && _selectedCameras.every((camera) => camera == null)) {
      // Only set up initial cameras for completely empty configuration
      final startIndex = _currentPage * maxCamerasPerPage;
      for (int i = 0; i < maxCamerasPerPage && startIndex + i < _availableCameras.length; i++) {
        _selectCameraForSlot(i, _availableCameras[startIndex + i]);
      }
    }
  }
  
  void _selectCameraForSlot(int slot, Camera camera) {
    if (slot < 0 || slot >= maxCamerasPerPage) return;
    
    setState(() {
      // Stop current player if it's playing
      if (_selectedCameras[slot] != null) {
        _players[slot].stop();
      }
      
      // Update selected camera for this slot
      _selectedCameras[slot] = camera;
      _errorStates[slot] = false;
      _loadingStates[slot] = true;
    });
    
    // Start playing the new camera
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
  
  void _clearSlot(int slot) {
    if (slot < 0 || slot >= maxCamerasPerPage) return;
    
    // Stop the player
    _players[slot].stop();
    
    setState(() {
      _selectedCameras[slot] = null;
      _errorStates[slot] = false;
      _loadingStates[slot] = false;
    });
  }
  
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
                        'Slot ${slot + 1} (Sayfa ${_currentPage + 1}) - Kamera Seç',
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
                    // Tüm kameraları göster - sayfa kısıtlaması olmadan
                    itemCount: _availableCameras.length,
                    itemBuilder: (context, index) {
                      final camera = _availableCameras[index];
                      // Belirli slotta bu kameranın seçili olup olmadığını kontrol et
                      final isSelected = _selectedCameras[slot] == camera;
                      
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
  
  void _changePage(int page) {
    if (page < 0 || page >= _totalPages) return;
    
    setState(() {
      _currentPage = page;
      // Do not load cameras automatically - we want to keep the player configuration
      // between pages and allow manual assignment of cameras to any slot
    });
  }
  
  void _changeGridLayout(int columns) {
    setState(() {
      _gridColumns = columns;
    });
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
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final size = MediaQuery.of(context).size;
    
    // Calculate available height for the grid
    final appBarHeight = AppBar().preferredSize.height;
    final paginationControlsHeight = _totalPages > 1 ? 60.0 : 0.0;
    final bottomNavHeight = 56.0;
    
    // Calculate available height for the grid
    final availableHeight = size.height - appBarHeight - paginationControlsHeight - bottomNavHeight;
    
    // Calculate number of rows based on the number of cameras and columns
    final displayedCameras = _availableCameras.isEmpty ? 
        maxCamerasPerPage : 
        math.min(maxCamerasPerPage, _availableCameras.length - (_currentPage * maxCamerasPerPage));
    final rowCount = (displayedCameras / _gridColumns).ceil();
    
    // Calculate the cell height to ensure no vertical scrolling is needed
    final gridHeight = availableHeight - 16; // Account for padding
    final cellHeight = (gridHeight / rowCount) - 8; // Account for grid spacing
    
    // Calculate the cell width based on the 16:9 aspect ratio
    final cellWidth = cellHeight * 16 / 9;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi Camera View'),
        actions: [
          // Grid layout selector
          PopupMenuButton<int>(
            tooltip: 'Change grid layout',
            icon: const Icon(Icons.grid_view),
            onSelected: _changeGridLayout,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 1,
                child: Text('1 column'),
              ),
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
            ],
          ),
          
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Fixed-height grid view of cameras (non-scrollable)
          // Ensuring all players fit within the screen with proper aspect ratio
          Container(
            height: gridHeight,
            child: GridView.builder(
              padding: const EdgeInsets.all(8.0),
              physics: const NeverScrollableScrollPhysics(), // Prevent scrolling
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridColumns,
                childAspectRatio: 16 / 9, // Maintain 16:9 aspect ratio
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: maxCamerasPerPage,
              itemBuilder: (context, index) {
                final camera = _selectedCameras[index];
                final isLoading = _loadingStates[index];
                final hasError = _errorStates[index];
                
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showCameraSelector(index),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Camera slot
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
                                  onPressed: () => _selectCameraForSlot(index, camera),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(80, 28),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          // Video player
                          Video(
                            controller: _controllers[index],
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
                                onPressed: () => _showCameraSelector(index),
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
          
          // Pagination controls at the bottom
          if (_totalPages > 1)
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
                    onPressed: _currentPage > 0
                        ? () => _changePage(_currentPage - 1)
                        : null,
                  ),
                  
                  // Page indicator with numbers
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < _totalPages; i++)
                        if (i == _currentPage)
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
                            onTap: () => _changePage(i),
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
                    onPressed: _currentPage < _totalPages - 1
                        ? () => _changePage(_currentPage + 1)
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
