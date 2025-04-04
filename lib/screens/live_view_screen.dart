import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
// Removed the import for media_kit_video_controls
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import "../widgets/video_controls.dart";
import '../utils/responsive_helper.dart';

class LiveViewScreen extends StatefulWidget {
  const LiveViewScreen({Key? key}) : super(key: key);

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  int _selectedCameraIndex = 0;
  final List<String> _layoutOptions = ['Single', '2x2', '3x3', '4x4'];
  String _selectedLayout = 'Single';
  
  // Map to store MediaKit players for each camera
  final Map<String, Player> _players = {};
  final Map<String, VideoController> _videoControllers = {};
  final Map<String, bool> _playerInitialized = {};
  
  @override
  void initState() {
    super.initState();
    
    // Initialize player for the currently selected camera after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSelectedCamera();
    });
  }
  
  void _initializeSelectedCamera() {
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    final selectedCamera = cameraDevicesProvider.selectedCamera;
    
    if (selectedCamera != null) {
      _initializePlayer(selectedCamera);
    }
  }

  Future<void> _initializePlayer(Camera camera) async {
    try {
      // Create player if it doesn't exist yet for this camera
      if (!_players.containsKey(camera.name)) {
        debugPrint('Creating new player for camera: ${camera.name}');
        _players[camera.name] = Player();
        _videoControllers[camera.name] = VideoController(_players[camera.name]!);
        _playerInitialized[camera.name] = false;
      }
      
      // Skip if already initialized
      if (_playerInitialized[camera.name] == true) {
        debugPrint('Player already initialized for camera: ${camera.name}');
        return;
      }
      
      String streamUrl = camera.rtspUri;
      
      if (streamUrl.isEmpty) {
        debugPrint('No stream URL available for camera: ${camera.name}');
        return;
      }
      
      debugPrint('Initializing player with stream URL: $streamUrl');
      
      // Open the media with the player
      await _players[camera.name]!.open(Media(streamUrl));
      
      if (mounted) {
        setState(() {
          _playerInitialized[camera.name] = true;
        });
      }
      
    } catch (e) {
      debugPrint('Error initializing player for ${camera.name}: $e');
    }
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
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live View'),
        backgroundColor: AppTheme.darkBackground,
        actions: [
          // Layout selector
          PopupMenuButton<String>(
            icon: const Icon(Icons.grid_view),
            onSelected: (String layout) {
              setState(() {
                _selectedLayout = layout;
              });
            },
            itemBuilder: (context) {
              return _layoutOptions.map((String layout) {
                return PopupMenuItem<String>(
                  value: layout,
                  child: Text(layout),
                );
              }).toList();
            },
          ),
          
          // More options
          PopupMenuButton<String>(
            onSelected: (String option) {
              // Handle option selection
            },
            itemBuilder: (context) {
              return [
                const PopupMenuItem<String>(
                  value: 'fullscreen',
                  child: Text('Fullscreen'),
                ),
                const PopupMenuItem<String>(
                  value: 'snapshot',
                  child: Text('Take Snapshot'),
                ),
                const PopupMenuItem<String>(
                  value: 'record',
                  child: Text('Start Recording'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Consumer<CameraDevicesProvider>(
        builder: (context, provider, child) {
          final allCameras = provider.allCameras;
          
          if (allCameras.isEmpty) {
            return const Center(
              child: Text(
                'No cameras available.\nMake sure you are connected to the server.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }
          
          // Filter for only connected cameras
          final connectedCameras = allCameras.where((camera) => camera.connected).toList();
          
          if (connectedCameras.isEmpty) {
            return const Center(
              child: Text(
                'No connected cameras found.\nAll cameras are currently offline.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }
          
          // Get the selected camera or use the first one
          final selectedCamera = provider.selectedCamera ?? connectedCameras.first;
          
          // Initialize the player for the selected camera if needed
          if (!_players.containsKey(selectedCamera.name)) {
            _initializePlayer(selectedCamera);
          }
          
          return Row(
            children: [
              // Camera list sidebar (only on desktop)
              if (isDesktop)
                SizedBox(
                  width: 250,
                  child: _buildCameraList(connectedCameras, selectedCamera),
                ),
                
              // Main content area
              Expanded(
                child: Column(
                  children: [
                    // Camera view
                    Expanded(
                      child: _buildCameraView(selectedCamera),
                    ),
                    
                    // Bottom camera selector (only on mobile)
                    if (!isDesktop)
                      SizedBox(
                        height: 100,
                        child: _buildCameraSelector(connectedCameras, selectedCamera),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildCameraList(List<Camera> cameras, Camera selectedCamera) {
    return Container(
      color: AppTheme.darkSurface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Cameras',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: cameras.length,
              itemBuilder: (context, index) {
                final camera = cameras[index];
                final isSelected = camera.name == selectedCamera.name;
                
                return ListTile(
                  leading: const Icon(Icons.videocam),
                  title: Text(
                    camera.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    camera.manufacturer.isNotEmpty || camera.hw.isNotEmpty
                        ? '${camera.manufacturer} ${camera.hw}'
                        : 'Camera ${index + 1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
                  trailing: camera.recording
                      ? const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12)
                      : null,
                  onTap: () {
                    // Find the device this camera belongs to
                    final provider = Provider.of<CameraDevicesProvider>(context, listen: false);
                    for (var device in provider.devicesList) {
                      int cameraIndex = device.cameras.indexWhere((c) => c.name == camera.name);
                      if (cameraIndex >= 0) {
                        provider.setSelectedDevice(device.macKey);
                        provider.setSelectedCameraIndex(cameraIndex);
                        
                        // Initialize the player for this camera if needed
                        _initializePlayer(camera);
                        break;
                      }
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCameraSelector(List<Camera> cameras, Camera selectedCamera) {
    return Container(
      color: AppTheme.darkSurface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cameras.length,
        itemBuilder: (context, index) {
          final camera = cameras[index];
          final isSelected = camera.name == selectedCamera.name;
          
          return Container(
            width: 120,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: () {
                // Find the device this camera belongs to
                final provider = Provider.of<CameraDevicesProvider>(context, listen: false);
                for (var device in provider.devicesList) {
                  int cameraIndex = device.cameras.indexWhere((c) => c.name == camera.name);
                  if (cameraIndex >= 0) {
                    provider.setSelectedDevice(device.macKey);
                    provider.setSelectedCameraIndex(cameraIndex);
                    
                    // Initialize the player for this camera if needed
                    _initializePlayer(camera);
                    break;
                  }
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam,
                    color: isSelected ? AppTheme.primaryColor : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    camera.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildCameraView(Camera camera) {
    // Check if player exists and is initialized
    final hasPlayer = _players.containsKey(camera.name);
    final isInitialized = _playerInitialized[camera.name] ?? false;
    
    if (!hasPlayer || !isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading camera: ${camera.name}',
              style: const TextStyle(fontSize: 16),
            ),
            if (camera.rtspUri.isEmpty)
              Text(
                'No stream URL available for this camera',
                style: TextStyle(fontSize: 14, color: Colors.red[300]),
              ),
          ],
        ),
      );
    }
    
    // Show the video view
    return Stack(
      children: [
        // Video
        Positioned.fill(
          child: Center(
            child: Video(
              controller: _videoControllers[camera.name]!,
              controls: (state) => VideoControls(state),
            ),
          ),
        ),
        
        // Camera info overlay
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  camera.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (camera.manufacturer.isNotEmpty || camera.hw.isNotEmpty)
                  Text(
                    '${camera.manufacturer} ${camera.hw}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                if (camera.recordWidth > 0 && camera.recordHeight > 0)
                  Text(
                    '${camera.recordWidth}x${camera.recordHeight}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Recording indicator
        if (camera.recording)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    size: 12,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'REC',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
