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

class _LiveViewScreenState extends State<LiveViewScreen> with SingleTickerProviderStateMixin {
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
  
  // Animation controllers
  late AnimationController _pageAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePlayer();
  }
  
  void _initializeAnimations() {
    // Setup animations
    _pageAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pageAnimationController,
      curve: Curves.easeIn,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageAnimationController,
      curve: Curves.easeOutQuint,
    ));
    
    // Start the entrance animation
    _pageAnimationController.forward();
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
    if (index >= 0 && index < _availableCameras.length && index != _selectedCameraIndex) {
      // Start a transition animation when changing cameras
      _pageAnimationController.reset();
      
      setState(() {
        _selectedCameraIndex = index;
        _camera = _availableCameras[index];
      });
      
      // Load the newly selected camera
      _loadCameraStream();
      
      // Start the animation for the new camera
      _pageAnimationController.forward();
    }
  }
  
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }
  
  Future<void> _showCameraDetails() async {
    // Show a smooth animated modal sheet
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFullCameraDetails(),
      // Use animation settings
      transitionAnimationController: AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: Navigator.of(context).overlay!,
      ),
    );
  }
  
  @override
  void dispose() {
    _pageAnimationController.dispose();
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
          mini: true,
          onPressed: _toggleFullScreen,
          child: const Icon(Icons.fullscreen_exit),
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
            tooltip: 'Fullscreen',
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
                      child: AnimatedList(
                        initialItemCount: _availableCameras.length,
                        itemBuilder: (context, index, animation) {
                          final camera = _availableCameras[index];
                          final isSelected = index == _selectedCameraIndex;
                          
                          // Animated list item for each camera
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(-1, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutQuad,
                            )),
                            child: FadeTransition(
                              opacity: animation,
                              child: ListTile(
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
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            
            // Right side with player and details
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
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
        // Video player with HeroMode activated for smooth transitions
        Hero(
          tag: 'player_${_camera!.id}',
          child: Material(
            type: MaterialType.transparency,
            child: Video(
              controller: _controller,
              controls: (_) => VideoControls(player: _player),
            ),
          ),
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
                onPressed: _showCameraDetails,
                tooltip: 'More Info',
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            // Wrap with ValueKey to trigger animation when camera changes
            child: Wrap(
              key: ValueKey<String>(_camera!.id),
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.camera_alt, 'Name: ${_camera!.name}'),
                _buildInfoChip(Icons.language, 'IP: ${_camera!.ip}'),
                if (_camera!.manufacturer.isNotEmpty)
                  _buildInfoChip(Icons.business, 'Manufacturer: ${_camera!.manufacturer}'),
                if (_camera!.brand.isNotEmpty)
                  _buildInfoChip(Icons.category, 'Brand: ${_camera!.brand}'),
              ],
            ),
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
      elevation: 2,
      shadowColor: Colors.black45,
    );
  }
  
  Widget _buildFullCameraDetails() {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Draggable handle indicator
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info, size: 28, color: AppTheme.primaryOrange),
                        const SizedBox(width: 12),
                        Text(
                          'Camera Details',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildDetailItem('Name', _camera!.name),
                    _buildDetailItem('IP Address', _camera!.ip),
                    _buildDetailItem('ID', _camera!.id), // Using ID instead of MAC address
                    _buildDetailItem('Manufacturer', _camera!.manufacturer),
                    _buildDetailItem('Brand', _camera!.brand), // Using Brand instead of Model
                    _buildDetailItem('RTSP URI', _camera!.rtspUri),
                    _buildDetailItem('Country', _camera!.country),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildDetailItem(String title, String value) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuint,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Padding(
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
      ),
    );
  }
}
