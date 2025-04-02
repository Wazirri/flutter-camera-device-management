import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';                    // For Player
import 'package:media_kit_video/media_kit_video.dart';        // For Video widget
import 'package:provider/provider.dart';                      // For Provider
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/status_indicator.dart';
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';

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
  final Map<int, Player> _players = {};
  final Map<int, VideoController> _videoControllers = {};
  final Map<int, bool> _playerInitialized = {};
  
  // Demo video URL as fallback
  final String _demoVideoUrl = 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4';
  
  @override
  void initState() {
    super.initState();
    
    // Initialize players for all cameras
    for (int i = 0; i < 10; i++) {
      _players[i] = Player();
      _videoControllers[i] = VideoController(_players[i]!);
      _playerInitialized[i] = false;
    }
    
    // Initialize player for the currently selected camera
    _initializePlayer(_selectedCameraIndex);
  }
  
  Future<void> _initializePlayer(int cameraIndex) async {
    try {
      // Get camera devices from provider
      final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
      final cameras = cameraDevicesProvider.allCameras;
      
      String streamUrl;
      
      // If we have data for this camera index, use its RTSP stream
      if (cameras.length > cameraIndex) {
        final camera = cameras[cameraIndex];
        streamUrl = camera.rtspUri;
      } else {
        // Otherwise use the demo video
        streamUrl = _demoVideoUrl;
      }
      
      // Open the media with the player
      await _players[cameraIndex]!.open(Media(streamUrl));
      
      if (mounted) {
        setState(() {
          _playerInitialized[cameraIndex] = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing player for camera $cameraIndex: $e');
      // Try with demo video as fallback
      try {
        await _players[cameraIndex]!.open(Media(_demoVideoUrl));
        if (mounted) {
          setState(() {
            _playerInitialized[cameraIndex] = true;
          });
        }
      } catch (e2) {
        debugPrint('Error initializing player with demo video: $e2');
      }
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
      backgroundColor: AppTheme.darkBackground,
      appBar: CustomAppBar(
        title: 'Live View',
        isDesktop: isDesktop,
        actions: [
          _buildLayoutSelector(),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Camera list sidebar - only visible on desktop/tablet
          if (isDesktop || ResponsiveHelper.isTablet(context))
            SizedBox(
              width: 280,
              child: Card(
                margin: EdgeInsets.zero,
                color: AppTheme.darkSurface,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search cameras',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppTheme.darkBackground,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: 10,
                        itemBuilder: (context, index) {
                          return _buildCameraListItem(
                            index: index,
                            isSelected: _selectedCameraIndex == index,
                            onTap: () {
                              setState(() {
                                _selectedCameraIndex = index;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Main content area
          Expanded(
            child: Column(
              children: [
                // Live video display area
                Expanded(
                  child: _buildSelectedLayout(context),
                ),
                
                // Bottom control bar
                _buildControlBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: DropdownButton<String>(
        value: _selectedLayout,
        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.darkTextPrimary),
        iconSize: 24,
        elevation: 16,
        style: const TextStyle(color: AppTheme.darkTextPrimary),
        underline: Container(height: 0),
        dropdownColor: AppTheme.darkSurface,
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedLayout = newValue;
            });
          }
        },
        items: _layoutOptions.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Row(
              children: [
                Icon(
                  _getLayoutIcon(value),
                  color: AppTheme.darkTextPrimary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(value),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getLayoutIcon(String layout) {
    switch (layout) {
      case 'Single':
        return Icons.fullscreen;
      case '2x2':
        return Icons.grid_view;
      case '3x3':
        return Icons.apps;
      case '4x4':
        return Icons.dashboard;
      default:
        return Icons.fullscreen;
    }
  }

  Widget _buildSelectedLayout(BuildContext context) {
    switch (_selectedLayout) {
      case 'Single':
        return _buildSingleCameraView();
      case '2x2':
        return _buildGridLayout(2);
      case '3x3':
        return _buildGridLayout(3);
      case '4x4':
        return _buildGridLayout(4);
      default:
        return _buildSingleCameraView();
    }
  }

  Widget _buildSingleCameraView() {
    // Check if selected camera player is initialized
    final bool isPlayerInitialized = _playerInitialized[_selectedCameraIndex] ?? false;
    
    // Get camera information if available
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    final cameras = cameraDevicesProvider.allCameras;
    final bool hasCameraData = cameras.length > _selectedCameraIndex;
    
    // Initialize the player if needed
    if (!isPlayerInitialized) {
      _initializePlayer(_selectedCameraIndex);
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias, // Ensure video doesn't overflow rounded corners
      child: Stack(
        children: [
          // Video player or placeholder based on camera selection
          if (isPlayerInitialized)
            // Camera with video player
            SizedBox.expand(
              child: Video(
                controller: _videoControllers[_selectedCameraIndex]!,
                controls: NoVideoControls, // Use custom controls instead
                wakelock: false, // We'll handle wakelock ourselves
                fit: BoxFit.contain, // Contain the video in the available space
              ),
            )
          else
            // Placeholder for cameras that aren't initialized yet
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_off,
                    size: 64,
                    color: AppTheme.darkTextSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Camera ${_selectedCameraIndex + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasCameraData ? 'Loading video feed...' : 'No live feed available',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          
          // Camera info overlay
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  StatusIndicator(
                    status: hasCameraData ? 
                      (cameras[_selectedCameraIndex].isConnected ? DeviceStatus.online : DeviceStatus.offline) : 
                      DeviceStatus.unknown,
                    size: 8,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasCameraData ? cameras[_selectedCameraIndex].name : 'Camera ${_selectedCameraIndex + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Recording indicator if applicable
          if (hasCameraData && cameras[_selectedCameraIndex].isRecording)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 10,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'REC',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Timestamp overlay
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                DateTime.now().toString().substring(0, 19), // Current time as timestamp
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridLayout(int gridSize) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridSize,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: gridSize * gridSize,
      itemBuilder: (context, index) {
        return _buildGridCameraItem(index);
      },
    );
  }

  Widget _buildGridCameraItem(int index) {
    // Check if this camera's player is initialized
    final bool isPlayerInitialized = _playerInitialized[index] ?? false;
    
    // Get camera information if available
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    final cameras = cameraDevicesProvider.allCameras;
    final bool hasCameraData = cameras.length > index;
    
    // Initialize the player for grid view if needed and not already initialized
    if (!isPlayerInitialized) {
      _initializePlayer(index);
    }
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCameraIndex = index;
          _selectedLayout = 'Single';
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: index == _selectedCameraIndex && _selectedLayout != 'Single'
              ? Border.all(color: AppTheme.primaryBlue, width: 2)
              : null,
        ),
        clipBehavior: Clip.antiAlias, // For video rendering
        child: Stack(
          children: [
            // Video or placeholder for the camera
            if (isPlayerInitialized)
              // Show the video for this camera
              SizedBox.expand(
                child: Video(
                  controller: _videoControllers[index]!,
                  controls: NoVideoControls,
                  fit: BoxFit.cover,
                ),
              )
            else
              // Placeholder for cameras without initialized players
              Center(
                child: Icon(
                  Icons.videocam_off,
                  size: 32,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            
            // Camera name overlay
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    StatusIndicator(
                      status: hasCameraData ? 
                        (cameras[index].isConnected ? DeviceStatus.online : DeviceStatus.offline) : 
                        (index % 5 == 0 ? DeviceStatus.offline : DeviceStatus.online),
                      size: 6,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasCameraData ? cameras[index].name : 'Camera ${index + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Recording indicator if applicable
            if (hasCameraData && cameras[index].isRecording)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        size: 8,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'REC',
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraListItem({
    required int index,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    bool isOnline = index % 5 != 0;
    
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppTheme.primaryBlue.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Icon(
            Icons.videocam,
            color: isOnline ? AppTheme.primaryBlue : AppTheme.darkTextSecondary,
            size: 20,
          ),
        ),
      ),
      title: Text(
        'Camera ${index + 1}',
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryBlue : AppTheme.darkTextPrimary,
        ),
      ),
      subtitle: Row(
        children: [
          StatusIndicator(
            status: isOnline ? DeviceStatus.online : DeviceStatus.offline,
            size: 8,
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkTextSecondary,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.camera_enhance_rounded),
            iconSize: 18,
            color: isSelected ? AppTheme.primaryBlue : AppTheme.darkTextSecondary,
            onPressed: () {
              Navigator.pushNamed(context, '/camera-devices');
            },
            tooltip: 'View Camera Details',
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: isSelected ? AppTheme.primaryBlue : AppTheme.darkTextSecondary,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildControlBar() {
    // Get the currently selected camera's player
    final bool isPlayerInitialized = _playerInitialized[_selectedCameraIndex] ?? false;
    final Player? currentPlayer = isPlayerInitialized ? _players[_selectedCameraIndex] : null;
    
    // Get playback state for the selected camera
    final bool isPlayingVideo = isPlayerInitialized && 
                               currentPlayer != null && 
                               currentPlayer.state.playing;
    
    // Get volume state for the selected camera
    final bool isMuted = isPlayerInitialized && 
                        currentPlayer != null && 
                        currentPlayer.state.volume <= 0;
    
    return Container(
      height: 60,
      color: AppTheme.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left controls
          Row(
            children: [
              // Play/Pause button for the selected camera
              _buildControlButton(
                icon: isPlayingVideo ? Icons.pause : Icons.play_arrow,
                label: isPlayingVideo ? 'Pause' : 'Play',
                onPressed: () {
                  if (isPlayerInitialized && currentPlayer != null) {
                    if (isPlayingVideo) {
                      currentPlayer.pause();
                    } else {
                      currentPlayer.play();
                    }
                    setState(() {}); // Refresh UI to update button state
                  }
                },
                enabled: isPlayerInitialized,
              ),
              _buildControlButton(
                icon: Icons.fullscreen,
                label: 'Fullscreen',
                onPressed: () {
                  // UI only for now
                },
                enabled: isPlayerInitialized,
              ),
              _buildControlButton(
                icon: Icons.screenshot,
                label: 'Screenshot',
                onPressed: () {
                  // UI only for now
                },
                enabled: isPlayerInitialized,
              ),
              _buildControlButton(
                icon: Icons.fiber_manual_record,
                label: 'Record',
                onPressed: () {
                  // UI only for now
                },
                iconColor: AppTheme.error,
                enabled: isPlayerInitialized,
              ),
            ],
          ),
          
          // Right controls
          Row(
            children: [
              _buildControlButton(
                icon: isMuted ? Icons.volume_off : Icons.volume_up,
                label: isMuted ? 'Unmute' : 'Mute',
                onPressed: () {
                  if (isPlayerInitialized && currentPlayer != null) {
                    // Toggle mute
                    if (currentPlayer.state.volume > 0) {
                      currentPlayer.setVolume(0);
                    } else {
                      currentPlayer.setVolume(100);
                    }
                    setState(() {}); // Refresh UI
                  }
                },
                enabled: isPlayerInitialized,
              ),
              _buildControlButton(
                icon: Icons.settings,
                label: 'Settings',
                onPressed: () {
                  // UI only for now
                },
              ),
              _buildControlButton(
                icon: Icons.camera_enhance_rounded,
                label: 'Camera Details',
                onPressed: () {
                  Navigator.pushNamed(context, '/camera-devices');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? iconColor,
    bool enabled = true,
  }) {
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon),
        onPressed: enabled ? onPressed : null,
        color: enabled ? (iconColor ?? AppTheme.darkTextPrimary) : AppTheme.darkTextSecondary.withOpacity(0.5),
      ),
    );
  }
}