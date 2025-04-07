import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/camera_devices_provider.dart';
import '../providers/recording_provider.dart';
import '../models/camera_device.dart';
import '../models/recording.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';
import '../utils/responsive_helper.dart';
import '../utils/page_transitions.dart';

class RecordViewScreen extends StatefulWidget {
  final Camera? camera; // Make camera optional so the route can work without a parameter

  const RecordViewScreen({Key? key, this.camera}) : super(key: key);

  @override
  State<RecordViewScreen> createState() => _RecordViewScreenState();
}

class _RecordViewScreenState extends State<RecordViewScreen> with SingleTickerProviderStateMixin {
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
  bool _isLiveStream = true; // Track if showing live stream or recording
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _calendarSlideAnimation;
  late Animation<Offset> _playerSlideAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePlayer();
  }
  
  void _initializeAnimations() {
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    ));
    
    _calendarSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutQuint),
    ));
    
    _playerSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));
    
    // Start the entrance animation
    _animationController.forward();
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
      print('Player error: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to play video: $error';
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
      }
    });
    
    // Initialize the recording provider with the current camera
    if (_camera != null) {
      final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
      recordingProvider.selectCamera(_camera!);
      
      // Start playing live stream
      _playLiveStream();
    }
  }
  
  void _playLiveStream() {
    if (_camera == null || !mounted) return;
    
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _isLiveStream = true;
    });
    
    if (_camera!.rtspUri.isNotEmpty) {
      try {
        _player.open(Media(_camera!.rtspUri));
      } catch (e) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to play live stream: $e';
        });
      }
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = 'No live stream URL available';
      });
    }
  }
  
  void _playRecording(Recording recording) {
    if (!mounted) return;
    
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _isLiveStream = false;
    });
    
    try {
      _player.open(Media(recording.url));
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to play recording: $e';
      });
    }
  }
  
  void _selectCamera(int index) {
    if (index >= 0 && index < _availableCameras.length && index != _selectedCameraIndex) {
      // Reset animations for transition
      _animationController.reset();
      
      setState(() {
        _selectedCameraIndex = index;
        _camera = _availableCameras[index];
      });
      
      // Update recording provider
      final recordingProvider = Provider.of<RecordingProvider>(context, listen: false);
      recordingProvider.selectCamera(_camera!);
      
      // Play live stream for newly selected camera
      _playLiveStream();
      
      // Start animations for the new data
      _animationController.forward();
    }
  }
  
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
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
          child: const Icon(Icons.fullscreen_exit),
          onPressed: _toggleFullScreen,
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_camera != null 
          ? 'Recordings: ${_camera!.name}' 
          : 'Recordings'
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: _isPlaying ? _toggleFullScreen : null,
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
                                  color: isSelected ? AppTheme.primaryColor : null,
                                ),
                                selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
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
            
            // Right side with calendar, recordings list, and player
            Expanded(
              child: Column(
                children: [
                  // Player section
                  Expanded(
                    flex: 3,
                    child: SlideTransition(
                      position: _playerSlideAnimation,
                      child: FadeTransition(
                        opacity: _fadeInAnimation,
                        child: _buildPlayer(),
                      ),
                    ),
                  ),
                  
                  // Recording days and files
                  Expanded(
                    flex: 2,
                    child: _buildRecordingsList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(_isLiveStream ? Icons.fiber_manual_record : Icons.live_tv),
        backgroundColor: _isLiveStream ? Colors.grey : AppTheme.primaryColor,
        onPressed: _isLiveStream ? null : _playLiveStream,
        tooltip: _isLiveStream ? 'Currently live' : 'Switch to live stream',
      ),
    );
  }
  
  Widget _buildPlayer() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          Center(
            child: _camera != null
                ? AspectRatio(
                    aspectRatio: 16 / 9, // Default aspect ratio
                    child: Video(controller: _controller),
                  )
                : const Center(
                    child: Text(
                      'No Camera Selected',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
          ),
          
          // Loading indicator
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(),
            ),
          
          // Error message
          if (_hasError)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _playLiveStream,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          
          // Video controls
          if (_isPlaying && !_isBuffering && !_hasError)
            Positioned.fill(
              child: VideoControls(
                isPlaying: _player.state.playing,
                isMuted: _isMuted,
                isFullscreen: _isFullscreen,
                onPlayPause: () { _player.state.playing ? _player.pause() : _player.play(); },
                onMuteToggle: _toggleMute,
                onFullscreenToggle: _toggleFullScreen,
              ),

            ),
          
          // Live indicator
          if (_isLiveStream && _isPlaying && !_hasError)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
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
      ),
    );
  }
  
  Widget _buildRecordingsList() {
    return Consumer<RecordingProvider>(
      builder: (context, recordingProvider, child) {
        if (recordingProvider.isLoadingDays) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (recordingProvider.hasDaysError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  recordingProvider.errorMessage,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: recordingProvider.refresh,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }
        
        final recordingDays = recordingProvider.recordingDays;
        
        if (recordingDays.isEmpty) {
          return const Center(
            child: Text('No recording days available'),
          );
        }
        
        return Row(
          children: [
            // Recording days list (left side)
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recording Days',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh days',
                          onPressed: recordingProvider.refresh,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: recordingDays.length,
                      itemBuilder: (context, index) {
                        final day = recordingDays[index];
                        final isSelected = recordingProvider.selectedDay?.dateFormatted == day.dateFormatted;
                        
                        return ListTile(
                          title: Text(
                            DateFormat('yyyy-MM-dd').format(day.date),
                          ),
                          subtitle: Text(
                            DateFormat('EEEE').format(day.date),
                          ),
                          selected: isSelected,
                          selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
                          onTap: () => recordingProvider.selectDay(day),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Vertical divider
            const VerticalDivider(width: 1),
            
            // Recordings list for selected day (right side)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          recordingProvider.selectedDay != null
                              ? 'Recordings for ${DateFormat('yyyy-MM-dd').format(recordingProvider.selectedDay!.date)}'
                              : 'Recordings',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (recordingProvider.selectedDay != null)
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh recordings',
                            onPressed: recordingProvider.refreshCurrentDay,
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _buildRecordingsContent(recordingProvider),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildRecordingsContent(RecordingProvider recordingProvider) {
    if (recordingProvider.isLoadingRecordings) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (recordingProvider.hasRecordingsError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Text(
              recordingProvider.errorMessage,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: recordingProvider.refreshCurrentDay,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    
    final recordings = recordingProvider.recordings;
    
    if (recordings.isEmpty) {
      return const Center(
        child: Text('No recordings available for this day'),
      );
    }
    
    return ListView.builder(
      itemCount: recordings.length,
      itemBuilder: (context, index) {
        final recording = recordings[index];
        final isSelected = recordingProvider.selectedRecording?.url == recording.url;
        
        return ListTile(
          title: Text(recording.timeFormatted),
          subtitle: recording.size.isNotEmpty
              ? Text('Size: ${recording.size}')
              : null,
          leading: const Icon(Icons.video_file),
          trailing: recording.duration > 0
              ? Text(recording.durationFormatted)
              : null,
          selected: isSelected,
          selectedTileColor: AppTheme.accentColor.withOpacity(0.1),
          onTap: () {
            recordingProvider.selectRecording(recording);
            _playRecording(recording);
          },
        );
      },
    );
  }
  
  // Calendar marker widget
  Widget _buildMarker(int count) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor,
      ),
      width: 16,
      height: 16,
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
