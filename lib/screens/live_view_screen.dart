import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/camera_device.dart';
import '../providers/camera_devices_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';

class LiveViewScreen extends StatefulWidget {
  final Camera? initialCamera;
  
  const LiveViewScreen({Key? key, this.initialCamera}) : super(key: key);

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> with SingleTickerProviderStateMixin {
  // Video player
  late final Player _player;
  late final VideoController _controller;
  
  // Animation controller for page transitions
  late AnimationController _pageAnimationController;
  late Animation<double> _pageAnimation;
  
  // State variables
  Camera? _camera;
  List<Camera> _availableCameras = [];
  int _selectedCameraIndex = -1;
  bool _isFullscreen = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showDetails = false;
  bool _isMuted = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize video player
    _player = Player();
    _controller = VideoController(_player);
    
    // Set up animations
    _pageAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _pageAnimation = CurvedAnimation(
      parent: _pageAnimationController,
      curve: Curves.easeInOut,
    );
    
    // Use initial camera if provided
    if (widget.initialCamera != null) {
      _camera = widget.initialCamera;
    }
    
    // Set up player listener for errors
    _player.stream.error.listen((error) {
      print('Player error: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to play stream: $error';
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get the list of available cameras from provider
    final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    setState(() {
      _availableCameras = cameraProvider.getAllCameras();
      
      // If no camera was provided and there are available cameras, use the first one
      if (_camera == null && _availableCameras.isNotEmpty) {
        _camera = _availableCameras[0];
        _selectedCameraIndex = 0;
      } else if (_camera != null) {
        // Find index of initial camera
        _selectedCameraIndex = _availableCameras.indexWhere((c) => c.id == _camera!.id);
      }
      
      // Load the camera stream if we have a valid camera
      if (_camera != null) {
        _loadCameraStream();
      }
    });
  }
  
  void _loadCameraStream() {
    if (_camera == null || _camera!.subUri.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No valid RTSP stream URL available for this camera';
      });
      return;
    }
    
    // Reset error state
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    
    // Format RTSP URL if needed (sometimes RTSP URLs need adjustments)
    final url = _camera!.subUri;
    
    // Try to play the stream
    try {
      _player.open(Media(url));
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error opening stream: $e';
      });
    }
  }
  
  void _selectCamera(int index) {
    if (index >= 0 && index < _availableCameras.length && index != _selectedCameraIndex) {
      // Start a transition animation when changing cameras
      _pageAnimationController.reset();
      _pageAnimationController.forward();
      
      setState(() {
        _selectedCameraIndex = index;
        _camera = _availableCameras[index];
        
        // Play the new stream
        _loadCameraStream();
      });
      
      // Update the selected camera in the provider
      Provider.of<CameraDevicesProvider>(context, listen: false)
        .setSelectedCameraIndex(index);
    }
  }
  
  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }
  
  void _toggleMute() {
    final newValue = !_isMuted;
    setState(() {
      _isMuted = newValue;
    });
    _player.setVolume(newValue ? 0 : 100);
  }
  
  void _toggleDetails() {
    setState(() {
      _showDetails = !_showDetails;
    });
  }
  
  @override
  void dispose() {
    _pageAnimationController.dispose();
    _player.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullscreen 
          ? null 
          : AppBar(
              title: Text(_camera?.name ?? 'Live View'),
              actions: [
                IconButton(
                  icon: Icon(_showDetails ? Icons.info : Icons.info_outline),
                  tooltip: 'Camera Details',
                  onPressed: _toggleDetails,
                ),
              ],
            ),
      body: Column(
        children: [
          // Video Player Area
          Expanded(
            child: Stack(
              children: [
                // Video player
                _buildVideoPlayer(),
                
                // Camera selection drawer handle (if not in fullscreen)
                if (!_isFullscreen && _availableCameras.length > 1)
                  Positioned(
                    top: 16,
                    left: 0,
                    child: _buildCameraDrawerHandle(),
                  ),
                
                // Video controls overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildVideoControls(),
                ),
                
                // Error message overlay
                if (_hasError)
                  _buildErrorOverlay(),
                
                // Camera details panel
                if (_showDetails && !_isFullscreen)
                  _buildCameraDetails(),
              ],
            ),
          ),
          
          // Camera selection tabs (if not in fullscreen)
          if (!_isFullscreen && _availableCameras.length > 1)
            _buildCameraSelectionTabs(),
        ],
      ),
    );
  }
  
  Widget _buildVideoPlayer() {
    return Container(
      color: Colors.black,
      child: _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    onPressed: _loadCameraStream,
                  ),
                ],
              ),
            )
          : Center(
              child: AspectRatio(
                aspectRatio: 16 / 9, // Default aspect ratio, should be updated with actual camera info
                child: Material(
                  color: Colors.black,
                  child: InkWell(
                    onTap: () {
                      // Toggle UI visibility on tap
                    },
                    child: Stack(
                      children: [
                        // Actual video
                        Video(
                          controller: _controller,
                          controls: NoVideoControls,
                          fit: BoxFit.contain,
                        ),
                        
                        // Fade animation for camera transitions
                        FadeTransition(
                          opacity: _pageAnimation,
                          child: Container(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
  
  Widget _buildVideoControls() {
    return VideoControls(
      isPlaying: _player.state.playing,
      isMuted: _isMuted,
      isFullscreen: _isFullscreen,
      onPlayPause: () {
        if (_player.state.playing) {
          _player.pause();
        } else {
          _player.play();
        }
        setState(() {});
      },
      onMuteToggle: _toggleMute,
      onFullscreenToggle: _toggleFullscreen,
    );
  }
  
  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadCameraStream,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCameraSelectionTabs() {
    return Container(
      height: 60,
      color: AppTheme.darkSurface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableCameras.length,
        itemBuilder: (context, index) {
          final camera = _availableCameras[index];
          final isSelected = index == _selectedCameraIndex;
          
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectCamera(index),
              child: Container(
                width: 150,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppTheme.accentColor : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  color: isSelected ? AppTheme.accentColor.withOpacity(0.1) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      camera.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.accentColor : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      camera.ip,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildCameraDrawerHandle() {
    return GestureDetector(
      onTap: () {
        // TODO: Implement a drawer that slides in with camera list
      },
      child: Container(
        width: 24,
        height: 100,
        decoration: BoxDecoration(
          color: AppTheme.accentColor,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.chevron_right,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
  
  Widget _buildCameraDetails() {
    if (_camera == null) return const SizedBox.shrink();
    
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 300,
      child: Container(
        color: AppTheme.darkSurface.withOpacity(0.9),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Camera Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _showDetails = false),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  const Icon(Icons.info, size: 28, color: AppTheme.accentColor),
                  const SizedBox(height: 16),
                  _buildDetailItem('Name', _camera!.name),
                  _buildDetailItem('IP Address', _camera!.ip),
                  _buildDetailItem('Model', _camera!.model),
                  _buildDetailItem('Brand', _camera!.brand),
                  _buildDetailItem('RTSP URI', _camera!.subUri),
                  // // _buildDetailItem('Country', _camera!.country),
                  _buildDetailItem('Username', _camera!.username),
                  _buildDetailItem('Resolution', 
                    _camera!.subWidth > 0 
                        ? '${_camera!.subWidth}x${_camera!.subHeight}'
                        : 'Unknown'
                  ),
                  _buildDetailItem('Status', _camera!.connected ? 'Connected' : 'Disconnected'),
                  _buildDetailItem('Recording', _camera!.recording ? 'Yes' : 'No'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailItem(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
