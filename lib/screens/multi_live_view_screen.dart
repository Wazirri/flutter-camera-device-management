import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';
import '../utils/responsive_helper.dart';

class MultiLiveViewScreen extends StatefulWidget {
  const MultiLiveViewScreen({Key? key}) : super(key: key);

  @override
  State<MultiLiveViewScreen> createState() => _MultiLiveViewScreenState();
}

class _MultiLiveViewScreenState extends State<MultiLiveViewScreen> {
  static const int maxCamerasPerPage = 32;
  
  // State variables
  List<Camera> _availableCameras = [];
  final List<Camera?> _selectedCameras = List.filled(maxCamerasPerPage, null);
  final List<Player> _players = [];
  final List<VideoController> _controllers = [];
  final List<bool> _loadingStates = List.filled(maxCamerasPerPage, false);
  final List<bool> _errorStates = List.filled(maxCamerasPerPage, false);
  int _currentPage = 0;
  int _totalPages = 1;
  int _gridColumns = 2; // Default grid columns
  
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
      
      // Initialize all slots with available cameras
      for (int i = 0; i < maxCamerasPerPage && i < cameras.length; i++) {
        _selectCameraForSlot(i, cameras[i]);
      }
    });
    
    // Adjust grid columns based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) {
      _gridColumns = 4;
    } else if (screenWidth > 800) {
      _gridColumns = 3;
    } else {
      _gridColumns = 2;
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
                        'Slot ${slot + 1} - Select Camera',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _availableCameras.length,
                    itemBuilder: (context, index) {
                      final camera = _availableCameras[index];
                      final isSelected = _selectedCameras.contains(camera);
                      
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
                              ? 'Connected (${camera.ip})'
                              : 'Disconnected (${camera.ip})',
                        ),
                        trailing: camera.connected
                            ? const Icon(Icons.link, color: Colors.green)
                            : const Icon(Icons.link_off, color: Colors.red),
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
                Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Clear this slot'),
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
    
    // Stop all current players
    for (int i = 0; i < maxCamerasPerPage; i++) {
      if (_selectedCameras[i] != null) {
        _players[i].stop();
      }
    }
    
    setState(() {
      _currentPage = page;
      
      // Clear all slots
      for (int i = 0; i < maxCamerasPerPage; i++) {
        _selectedCameras[i] = null;
        _errorStates[i] = false;
        _loadingStates[i] = false;
      }
      
      // Fill slots with cameras from the new page
      final startIndex = page * maxCamerasPerPage;
      for (int i = 0; i < maxCamerasPerPage && startIndex + i < _availableCameras.length; i++) {
        _selectCameraForSlot(i, _availableCameras[startIndex + i]);
      }
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
            ],
          ),
          
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Grid view of cameras
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridColumns,
                childAspectRatio: 16 / 9,
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
                  const SizedBox(width: 16),
                  Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 16),
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

