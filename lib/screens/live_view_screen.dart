import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../providers/camera_devices_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';

class LiveViewScreen extends StatefulWidget {
  final Camera? camera; // Make camera optional so the route can work without a parameter

  const LiveViewScreen({
    Key? key,
    this.camera,
  }) : super(key: key);

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  // Media Kit player
  late final Player _player;
  late final VideoController _controller;
  Camera? _camera;
  bool _isFullScreen = false;
  bool _isLoading = true;
  bool _isMuted = false;
  List<Camera> _availableCameras = [];
  
  @override
  void initState() {
    super.initState();
    // Initialize the player
    _player = Player();
    _controller = VideoController(_player);
    _camera = widget.camera;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCamera();
    });
  }
  
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
  
  void _loadCamera() async {
    final provider = Provider.of<CameraDevicesProvider>(context, listen: false);
    
    // Get all available cameras
    setState(() {
      _availableCameras = provider.cameras;
      _isLoading = true;
    });
    
    // If no camera was passed, try to use the first one
    if (_camera == null && _availableCameras.isNotEmpty) {
      setState(() {
        _camera = _availableCameras.first;
      });
    }
    
    // If we have a camera, play it
    if (_camera != null) {
      _playCamera(_camera!);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _playCamera(Camera camera) async {
    setState(() {
      _isLoading = true;
      _camera = camera;
    });
    
    try {
      // Stop any current playback
      await _player.stop();
      
      // Check if we have a valid media URI
      if (camera.mediaUri.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No media URL available for ${camera.name}')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Log the media URI we're trying to play
      debugPrint('Playing media URI: ${camera.mediaUri}');
      
      // Set up media options with authentication if needed
      final Map<String, String> httpHeaders = {};
      final List<String> playbackOptions = [];
      
      if (camera.username.isNotEmpty && camera.password.isNotEmpty) {
        // For RTSP authentication
        playbackOptions.add('rtsp-user=${camera.username}');
        playbackOptions.add('rtsp-pass=${camera.password}');
      }
      
      // Start playback
      await _player.open(
        Media(
          camera.mediaUri,
          httpHeaders: httpHeaders,
        ),
        play: true,
      );
      
      // Wait a bit to check if playback started successfully
      await Future.delayed(const Duration(seconds: 3));
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error playing camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play camera: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _player.setVolume(_isMuted ? 0 : 100);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullScreen 
          ? null 
          : AppBar(
              title: Text(_camera?.name ?? 'Live View'),
              backgroundColor: AppTheme.darkNavBar,
              actions: [
                PopupMenuButton<Camera>(
                  icon: const Icon(Icons.switch_video),
                  tooltip: 'Switch Camera',
                  itemBuilder: (context) {
                    return _availableCameras.map((camera) {
                      return PopupMenuItem<Camera>(
                        value: camera,
                        child: Row(
                          children: [
                            Icon(
                              Icons.videocam,
                              color: _camera == camera 
                                  ? AppTheme.primaryOrange 
                                  : null,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                camera.name.isEmpty 
                                    ? 'Camera ${camera.index + 1}' 
                                    : camera.name,
                                style: TextStyle(
                                  fontWeight: _camera == camera 
                                      ? FontWeight.bold 
                                      : FontWeight.normal,
                                  color: _camera == camera 
                                      ? AppTheme.primaryOrange 
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  onSelected: (camera) {
                    _playCamera(camera);
                  },
                ),
              ],
            ),
      body: _camera == null
          ? _buildEmptyState()
          : Stack(
              children: [
                // Video player
                Center(
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Video(
                          controller: _controller,
                          controls: NoVideoControls,
                          fit: BoxFit.contain,
                        ),
                ),
                
                // Overlay controls
                if (!_isLoading)
                  Positioned.fill(
                    child: VideoControls(
                      isFullScreen: _isFullScreen,
                      isMuted: _isMuted,
                      onToggleFullScreen: _toggleFullScreen,
                      onToggleMute: _toggleMute,
                    ),
                  ),
                
                // Camera name and status overlay
                if (!_isLoading && !_isFullScreen)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _camera!.connected 
                                  ? Colors.green 
                                  : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _camera!.name.isEmpty 
                                ? 'Camera ${_camera!.index + 1}' 
                                : _camera!.name,
                            style: const TextStyle(
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off,
            size: 72,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Camera Selected',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a camera to view the live feed',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reload Cameras'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            onPressed: _loadCamera,
          ),
        ],
      ),
    );
  }
}
