import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../providers/camera_devices_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';

class RecordViewScreen extends StatefulWidget {
  final Camera? camera; // Make camera optional so the route can work without a parameter

  const RecordViewScreen({
    Key? key,
    this.camera,
  }) : super(key: key);

  @override
  State<RecordViewScreen> createState() => _RecordViewScreenState();
}

class _RecordViewScreenState extends State<RecordViewScreen> {
  // Media Kit player
  late final Player _player;
  late final VideoController _controller;
  Camera? _camera;
  bool _isFullScreen = false;
  bool _isLoading = true;
  bool _isMuted = false;
  List<Camera> _availableCameras = [];
  
  // Recording timeline
  DateTime _selectedDate = DateTime.now();
  
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
      _playRecording(_camera!);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _playRecording(Camera camera) async {
    setState(() {
      _isLoading = true;
      _camera = camera;
    });
    
    try {
      // Stop any current playback
      await _player.stop();
      
      // Check if we have a valid record URI
      if (camera.recordUri.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No recording URL available for ${camera.name}')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Log the record URI we're trying to play
      debugPrint('Playing record URI: ${camera.recordUri}');
      
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
          camera.recordUri,
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
      debugPrint('Error playing recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play recording: ${e.toString()}')),
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

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    // In a real app, we would load the recording for this date
    // For now, we just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loading recording for ${date.toString().split(' ')[0]}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullScreen 
          ? null 
          : AppBar(
              title: Text(_camera?.name ?? 'Recordings'),
              backgroundColor: AppTheme.darkNavBar,
              actions: [
                // Date picker button
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  tooltip: 'Select Date',
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppTheme.primaryOrange,
                              onPrimary: Colors.white,
                              surface: AppTheme.darkSurface,
                              onSurface: Colors.white,
                            ),
                            dialogBackgroundColor: AppTheme.darkBackground,
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      _onDateChanged(picked);
                    }
                  },
                ),
                // Camera selector
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
                    _playRecording(camera);
                  },
                ),
              ],
            ),
      body: _camera == null
          ? _buildEmptyState()
          : Column(
              children: [
                // Video player
                Expanded(
                  child: Stack(
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
                            isRecording: true,
                            onPlayPause: () {
                              if (_player.state.playing) {
                                _player.pause();
                              } else {
                                _player.play();
                              }
                              setState(() {});
                            },
                          ),
                        ),
                      
                      // Recording date overlay
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
                                const Icon(
                                  Icons.video_library,
                                  color: AppTheme.primaryOrange,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
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
                ),
                
                // Playback timeline and controls (non-fullscreen only)
                if (!_isFullScreen)
                  Container(
                    color: AppTheme.darkSurface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Current timestamp
                            Text(
                              _formatDuration(_player.state.position),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                            
                            // Seekbar
                            Expanded(
                              child: Slider(
                                value: _player.state.position.inSeconds.toDouble(),
                                max: _player.state.duration.inSeconds.toDouble() + 1.0,
                                min: 0.0,
                                activeColor: AppTheme.primaryOrange,
                                inactiveColor: Colors.grey[800],
                                onChanged: (value) {
                                  _player.seek(Duration(seconds: value.toInt()));
                                },
                              ),
                            ),
                            
                            // Total duration
                            Text(
                              _formatDuration(_player.state.duration),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        
                        // Playback controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Rewind 10s
                            IconButton(
                              icon: const Icon(Icons.replay_10),
                              color: Colors.white,
                              onPressed: () {
                                final newPosition = _player.state.position - const Duration(seconds: 10);
                                _player.seek(newPosition.isNegative ? Duration.zero : newPosition);
                              },
                            ),
                            
                            // Play/Pause
                            IconButton(
                              icon: Icon(
                                _player.state.playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                              ),
                              iconSize: 48,
                              color: AppTheme.primaryOrange,
                              onPressed: () {
                                if (_player.state.playing) {
                                  _player.pause();
                                } else {
                                  _player.play();
                                }
                                setState(() {});
                              },
                            ),
                            
                            // Forward 10s
                            IconButton(
                              icon: const Icon(Icons.forward_10),
                              color: Colors.white,
                              onPressed: () {
                                final newPosition = _player.state.position + const Duration(seconds: 10);
                                if (newPosition < _player.state.duration) {
                                  _player.seek(newPosition);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return hours == '00'
        ? '$minutes:$seconds'
        : '$hours:$minutes:$seconds';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
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
            'Select a camera to view recordings',
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
