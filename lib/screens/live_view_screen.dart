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
          if (_selectedCameraIndex == 0 && _isPlayerInitialized)
            // Camera 1 with video player for the demo video
            SizedBox.expand(
              child: Video(
                controller: _videoController,
                controls: NoVideoControls, // Use custom controls instead
                wakelock: false, // We'll handle wakelock ourselves
                fit: BoxFit.contain, // Contain the video in the available space
              ),
            )
          else
            // Placeholder for other cameras
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
                    'No live feed available',
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
                    status: DeviceStatus.online,
                    size: 8,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Camera ${_selectedCameraIndex + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
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
    final bool isCamera1 = index == 0;
    final bool hasVideo = isCamera1 && _isPlayerInitialized;
    
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
            if (hasVideo)
              // Show a preview for Camera 1
              SizedBox.expand(
                child: Video(
                  controller: _videoController,
                  controls: NoVideoControls,
                  fit: BoxFit.cover,
                ),
              )
            else
              // Placeholder for other cameras
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
                      status: index % 5 == 0 ? DeviceStatus.offline : DeviceStatus.online,
                      size: 6,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Camera ${index + 1}' + (hasVideo ? ' (Live)' : ''),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
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
    // Get playback state for Camera 1
    final bool isPlayingVideo = _selectedCameraIndex == 0 && 
                               _isPlayerInitialized && 
                               _player.state.playing;
    
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
              if (_selectedCameraIndex == 0 && _isPlayerInitialized)
                // Play/Pause button for Camera 1
                _buildControlButton(
                  icon: isPlayingVideo ? Icons.pause : Icons.play_arrow,
                  label: isPlayingVideo ? 'Pause' : 'Play',
                  onPressed: () {
                    if (isPlayingVideo) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                    setState(() {}); // Refresh UI to update button state
                  },
                ),
              _buildControlButton(
                icon: Icons.fullscreen,
                label: 'Fullscreen',
                onPressed: () {
                  // UI only
                },
              ),
              _buildControlButton(
                icon: Icons.screenshot,
                label: 'Screenshot',
                onPressed: () {
                  // UI only
                },
              ),
              _buildControlButton(
                icon: Icons.fiber_manual_record,
                label: 'Record',
                onPressed: () {
                  // UI only
                },
                iconColor: AppTheme.error,
              ),
            ],
          ),
          
          // Right controls
          Row(
            children: [
              _buildControlButton(
                icon: (_selectedCameraIndex == 0 && _isPlayerInitialized && _player.state.volume <= 0) 
                      ? Icons.volume_off 
                      : Icons.volume_up,
                label: (_selectedCameraIndex == 0 && _isPlayerInitialized && _player.state.volume <= 0)
                      ? 'Unmute'
                      : 'Mute',
                onPressed: () {
                  if (_selectedCameraIndex == 0 && _isPlayerInitialized) {
                    // Toggle mute
                    if (_player.state.volume > 0) {
                      _player.setVolume(0);
                    } else {
                      _player.setVolume(100);
                    }
                    setState(() {}); // Refresh UI
                  }
                },
              ),
              _buildControlButton(
                icon: Icons.settings,
                label: 'Settings',
                onPressed: () {
                  // UI only
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
  }) {
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: iconColor ?? AppTheme.darkTextPrimary,
      ),
    );
  }
}