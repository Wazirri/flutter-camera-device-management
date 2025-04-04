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
  final Camera? camera; // Make camera optional so the route can work without a parameter

  const LiveViewScreen({Key? key, this.camera}) : super(key: key);

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  int _selectedCameraIndex = 0;
  Camera? _camera;
  bool _isFullScreen = false;
  late final Player _player;
  late final VideoController _controller;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _hasError = false;
  String _errorMessage = '';
  List<Camera> _availableCameras = [];
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }
  
  void _initializePlayer() {
    // Create a media kit player
    _player = Player();
    _controller = VideoController(_player);
    
    // Set initial camera if provided
    if (widget.camera != null) {
      _camera = widget.camera;
    }
    
    // Add event listeners
    _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });
    
    _player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          _isBuffering = buffering;
        });
      }
    });
    
    _player.stream.error.listen((error) {
      debugPrint('Player error: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to play stream: $error';
        });
      }
    });
    
    // Load the camera if available
    _loadCameraStream();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get the list of available cameras from provider
    final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    setState(() {
      _availableCameras = cameraProvider.cameras;
      
      // If no camera was provided and there are available cameras, use the first one
      if (_camera == null && _availableCameras.isNotEmpty) {
        _camera = _availableCameras[0];
        _loadCameraStream();
      }
    });
  }
  
  void _loadCameraStream() {
    if (_camera == null || _camera!.rtspUri.isEmpty) {
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
    final url = _camera!.rtspUri;
    
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
    if (index >= 0 && index < _availableCameras.length) {
      setState(() {
        _selectedCameraIndex = index;
        _camera = _availableCameras[index];
      });
      
      // Load the newly selected camera
      _loadCameraStream();
    }
  }
  
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }
  
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isFullScreen 
        ? null 
        : AppBar(
          title: Text(_camera != null 
            ? 'Live View: ${_camera!.name}' 
            : 'Live View'
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.fullscreen),
              onPressed: _toggleFullScreen,
            ),
          ],
        ),
      body: SafeArea(
        child: _isFullScreen
          ? _buildPlayer()
          : Column(
            children: [
              // Camera selector
              if (_availableCameras.length > 1)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableCameras.length,
                      itemBuilder: (context, index) {
                        final camera = _availableCameras[index];
                        final isSelected = index == _selectedCameraIndex;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text(camera.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                _selectCamera(index);
                              }
                            },
                            backgroundColor: Theme.of(context).cardColor,
                            selectedColor: AppTheme.primaryOrange.withOpacity(0.2),
                          ),
                        );
                      },
                    ),
                  ),
                ),
  
              // Player section
              Expanded(
                child: _buildPlayer(),
              ),
              
              // Camera details at the bottom
              if (_camera != null)
                _buildCameraDetails(),
            ],
          ),
      ),
      floatingActionButton: _isFullScreen 
        ? FloatingActionButton(
            child: const Icon(Icons.fullscreen_exit),
            onPressed: _toggleFullScreen,
          )
        : null,
    );
  }
  
  Widget _buildPlayer() {
    if (_camera == null) {
      return const Center(
        child: Text('No camera selected'),
      );
    }
    
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error playing stream',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadCameraStream,
            ),
          ],
        ),
      );
    }
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Video player
        Video(
          controller: _controller,
          controls: (player) => VideoControls(player: player),
        ),
        
        // Buffering indicator (show when buffering and not playing yet)
        if (_isBuffering && !_isPlaying)
          const CircularProgressIndicator(),
      ],
    );
  }
  
  Widget _buildCameraDetails() {
    if (_camera == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Camera name and status
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _camera!.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _camera!.connected ? Icons.link : Icons.link_off,
                        size: 16,
                        color: _camera!.connected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _camera!.connected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          color: _camera!.connected ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Resolution info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Main: ${_camera!.recordWidth}x${_camera!.recordHeight}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Sub: ${_camera!.subWidth}x${_camera!.subHeight}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          
          // Additional details
          const SizedBox(height: 8),
          if (_camera!.brand.isNotEmpty)
            Text('Brand: ${_camera!.brand}'),
          if (_camera!.ip.isNotEmpty)
            Text('IP: ${_camera!.ip}'),
        ],
      ),
    );
  }
}
