import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';
import '../utils/responsive_helper.dart';

class RecordViewScreen extends StatefulWidget {
  final Camera? camera; // Make camera optional so the route can work without a parameter

  const RecordViewScreen({Key? key, this.camera}) : super(key: key);

  @override
  State<RecordViewScreen> createState() => _RecordViewScreenState();
}

class _RecordViewScreenState extends State<RecordViewScreen> {
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
  List<String> _availableRecordings = [];
  String? _selectedRecording;
  
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
          _errorMessage = 'Failed to play recording: $error';
        });
      }
    });
    
    // Load the camera if available
    _fetchRecordings();
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
        _fetchRecordings();
      }
    });
  }
  
  // This would typically fetch recordings from a backend
  // For demo, we'll create some sample recordings
  void _fetchRecordings() {
    if (_camera == null) {
      setState(() {
        _availableRecordings = [];
      });
      return;
    }
    
    // In a real app, you'd fetch this from your backend
    // For demo, we'll simulate recordings
    setState(() {
      _availableRecordings = [
        '${_camera!.name} - Yesterday (10:00 AM)',
        '${_camera!.name} - Yesterday (2:30 PM)',
        '${_camera!.name} - Today (8:15 AM)',
      ];
      
      // Auto-select first recording if available
      if (_availableRecordings.isNotEmpty && _selectedRecording == null) {
        _selectedRecording = _availableRecordings[0];
        // In a real app, this URL would come from your backend
        _loadRecording(_camera!.recordUri);
      }
    });
  }
  
  void _loadRecording(String url) {
    if (url.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No recording URL available';
      });
      return;
    }
    
    // Reset error state
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    
    // Try to play the recording
    try {
      _player.open(Media(url));
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error opening recording: $e';
      });
    }
  }
  
  void _selectCamera(int index) {
    if (index >= 0 && index < _availableCameras.length) {
      setState(() {
        _selectedCameraIndex = index;
        _camera = _availableCameras[index];
        _selectedRecording = null;
      });
      
      // Fetch recordings for the newly selected camera
      _fetchRecordings();
    }
  }
  
  void _selectRecording(String recording) {
    setState(() {
      _selectedRecording = recording;
    });
    
    // In a real app, you'd fetch the recording URL from your backend
    // For demo, we'll use the camera's record URI
    if (_camera != null) {
      _loadRecording(_camera!.recordUri);
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
            ? 'Recordings: ${_camera!.name}' 
            : 'Recordings'
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
  
              // Recording selector
              if (_availableRecordings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Recording',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedRecording,
                    items: _availableRecordings.map((recording) {
                      return DropdownMenuItem<String>(
                        value: recording,
                        child: Text(recording),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _selectRecording(value);
                      }
                    },
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
    
    if (_selectedRecording == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.video_library,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _availableRecordings.isEmpty
                ? 'No recordings available'
                : 'Select a recording to play',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
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
              'Error playing recording',
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
              onPressed: () {
                if (_camera != null) {
                  _loadRecording(_camera!.recordUri);
                }
              },
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
                        _camera!.recording ? Icons.fiber_manual_record : Icons.stop,
                        size: 16,
                        color: _camera!.recording ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _camera!.recording ? 'Recording' : 'Not Recording',
                        style: TextStyle(
                          color: _camera!.recording ? Colors.red : Colors.grey,
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
                    'Recording: ${_camera!.recordWidth}x${_camera!.recordHeight}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_camera!.recordPath.isNotEmpty)
                    Text(
                      'Path: ${_camera!.recordPath}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ),
          
          // Selected recording
          if (_selectedRecording != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.video_file, size: 16),
                const SizedBox(width: 4),
                Text('Current: $_selectedRecording'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
