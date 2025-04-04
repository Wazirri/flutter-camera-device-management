import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';
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
      _loadCameraStream();
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
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    if (_isFullScreen) {
      return Scaffold(
        body: _buildPlayer(),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.fullscreen_exit),
          onPressed: _toggleFullScreen,
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
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
        child: Row(
          children: [
            // Left side panel with camera list
            if (_availableCameras.length > 1)
              Container(
                width: isDesktop ? 250 : 180,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Camera Devices',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _availableCameras.length,
                        itemBuilder: (context, index) {
                          final camera = _availableCameras[index];
                          final isSelected = index == _selectedCameraIndex;
                          
                          return ListTile(
                            title: Text(
                              camera.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: isSelected,
                            leading: Icon(
                              Icons.videocam,
                              color: isSelected ? AppTheme.primaryOrange : null,
                            ),
                            selectedTileColor: AppTheme.primaryOrange.withOpacity(0.1),
                            onTap: () => _selectCamera(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            
            // Right side with player and details
            Expanded(
              child: Column(
                children: [
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
          ],
        ),
      ),
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
          controls: (_) => VideoControls(player: _player),
        ),
        
        // Buffering indicator (show when buffering and not playing yet)
        if (_isBuffering && !_isPlaying)
          const CircularProgressIndicator(),
      ],
    );
  }
  
  Widget _buildCameraDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Camera Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  // Show more detailed camera info
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => _buildFullCameraDetails(),
                    isScrollControlled: true,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildInfoChip(Icons.camera_alt, 'Name: ${_camera!.name}'),
              _buildInfoChip(Icons.language, 'IP: ${_camera!.ip}'),
              if (_camera!.manufacturer.isNotEmpty)
                _buildInfoChip(Icons.business, 'Manufacturer: ${_camera!.manufacturer}'),
              if (_camera!.model.isNotEmpty)
                _buildInfoChip(Icons.category, 'Model: ${_camera!.model}'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    );
  }
  
  Widget _buildFullCameraDetails() {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ListView(
            controller: controller,
            children: [
              Text(
                'Camera Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(),
              _buildDetailItem('Name', _camera!.name),
              _buildDetailItem('IP Address', _camera!.ip),
              _buildDetailItem('MAC Address', _camera!.mac),
              _buildDetailItem('Manufacturer', _camera!.manufacturer),
              _buildDetailItem('Model', _camera!.model),
              _buildDetailItem('RTSP URI', _camera!.rtspUri),
              _buildDetailItem('Country', _camera!.country),
              const SizedBox(height: 24),
              ElevatedButton(
                child: const Text('Close'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildDetailItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$title:',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not available' : value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
