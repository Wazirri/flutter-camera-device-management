import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/camera_devices_provider_optimized.dart';
import '../providers/multi_view_layout_provider.dart';
import '../models/camera_device.dart';
import '../models/camera_layout.dart';
import 'dart:math' as math;

class MultiLiveViewScreen extends StatefulWidget {
  const MultiLiveViewScreen({Key? key}) : super(key: key);

  @override
  State<MultiLiveViewScreen> createState() => _MultiLiveViewScreenState();
}

class _MultiLiveViewScreenState extends State<MultiLiveViewScreen> with AutomaticKeepAliveClientMixin {
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
  bool _initialized = false;
  
  @override
  bool get wantKeepAlive => true; // Keep this widget alive when it's not visible
  
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
    
    // Only run this once to prevent reloading when dependencies change
    if (!_initialized) {
      _initialized = true;
      
      // Get available cameras from provider
      final cameraProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
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
        
        // Start streaming for all cameras, not just connected ones
        if (_players.isNotEmpty && i < _players.length) {
          _streamCamera(i, camera);
        }
      }
    }
  }
  
  // Stream camera at a specific slot
  void _streamCamera(int slotIndex, Camera camera) {
    if (!mounted) return;
    
    setState(() {
      _errorStates[slotIndex] = false; // Reset error state
      _loadingStates[slotIndex] = true; // Set loading state
    });
    
    if (slotIndex < _players.length) {
      final player = _players[slotIndex];
      
      // Check if camera has RTSP URL
      if (camera.rtspUri.isNotEmpty) {
        try {
          // Only open if player is not already playing something or has a different URL
          if (player.state.playlist.medias.isEmpty || 
              (player.state.playlist.medias.isNotEmpty && 
               player.state.playlist.medias.first.uri != camera.rtspUri)) {
            // Stop previous stream before loading new one
            player.stop();
            // Open new stream
            player.open(Media(camera.rtspUri));
          }
        } catch (e) {
          print('Error opening stream for camera ${camera.name}: $e');
          if (mounted) {
            setState(() {
              _errorStates[slotIndex] = true;
              _loadingStates[slotIndex] = false;
            });
          }
        }
      } else {
        // Handle no URL available
        if (mounted) {
          setState(() {
            _errorStates[slotIndex] = true;
            _loadingStates[slotIndex] = false;
          });
        }
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final cameraProvider = Provider.of<CameraDevicesProviderOptimized>(context);
    final layoutProvider = Provider.of<MultiViewLayoutProvider>(context);
    
    // Watch for layout changes (but don't update in didChangeDependencies)
    if (layoutProvider.currentLayout != null && 
        layoutProvider.currentLayout!.id != _currentLayout.id) {
      _currentLayout = layoutProvider.currentLayout!;
      _gridColumns = _currentLayout.columns;
      _updateGridColumnsBasedOnScreenSize();
    }
    
    // Check for new cameras (but don't reload existing ones)
    if (_availableCameras.isEmpty && cameraProvider.cameras.isNotEmpty) {
      _availableCameras = cameraProvider.cameras;
      _loadCamerasForCurrentPage();
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Multi Camera View', style: theme.textTheme.headlineSmall),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadCamerasForCurrentPage();
            },
          ),
        ],
      ),
      body: Container(
        width: size.width,
        height: size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
        color: Colors.black,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            final double availableHeight = constraints.maxHeight;
            
            // Calculate how many rows we need based on columns
            final int rows = (maxCamerasPerPage / _gridColumns).ceil();
            
            // Calculate item size to fill the available space exactly
            final double itemWidth = availableWidth / _gridColumns;
            final double itemHeight = availableHeight / rows;
            
            // Print slot coordinates (x1,y1,x2,y2) for each slot
            for (int i = 0; i < maxCamerasPerPage; i++) {
              // Calculate the grid position (row, column)
              final int row = i ~/ _gridColumns;
              final int column = i % _gridColumns;
              
              // Calculate coordinates based on layout - sağ alt köşe (0,0) kabul edilerek
              // Bu durumda sol üst köşe (width, height) olur ve değerler negatif olur
              
              // Sağ alt köşeden (0,0) hesaplanan koordinatlar
              final double rightBottomX1 = ((_gridColumns - column - 1) * itemWidth);
              final double rightBottomY1 = ((rows - row - 1) * itemHeight);
              final double rightBottomX2 = rightBottomX1 - itemWidth;
              final double rightBottomY2 = rightBottomY1 - itemHeight;
              
              // Ekranda gerçek piksel koordinatları (sol üst köşe)
              final double x1 = column * itemWidth;
              final double y1 = row * itemHeight;
              final double x2 = x1 + itemWidth;
              final double y2 = y1 + itemHeight;
              
              // Print sağ alt köşeye göre hesaplanan koordinatlar
              print('FSAAAA FSAAAA FSAAAA FSAAAA  Slot ${i+1} (index $i):');
              print('  Sağ alt köşeden (0,0) koordinatlar: x1=$rightBottomX1, y1=$rightBottomY1, x2=$rightBottomX2, y2=$rightBottomY2');
              print('  Karşılaştırma için Sol üst köşeden koordinatlar: x1=$x1, y1=$y1, x2=$x2, y2=$y2');
            }
            
            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridColumns,
                childAspectRatio: itemWidth / itemHeight,
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
              ),
              itemCount: maxCamerasPerPage,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final camera = index < _selectedCameras.length ? _selectedCameras[index] : null;
                
                if (camera != null) { // Tüm kameraları göster, bağlantı durumuna bakılmaksızın
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video player
                      ClipRect(
                        child: index < _controllers.length
                            ? RepaintBoundary(
                                child: Video(
                                  controller: _controllers[index],
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(child: Text('No player available')),
                      ),
                      
                      // Loading indicator
                      if (_loadingStates[index])
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                      
                      // Error indicator
                      if (_errorStates[index])
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 32),
                              SizedBox(height: 8),
                              Text(
                                'Stream Error',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      
                      // Camera name overlay
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
                      
                      // Camera status overlay
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
                      
                      // Make the entire cell tappable
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
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
                  // Show empty slot
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
            );
          },
        ),
      ),
    );
  }
}
