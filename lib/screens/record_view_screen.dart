import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
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
  
  // Calendar related variables
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final kFirstDay = DateTime(DateTime.now().year - 1, 1, 1);
  final kLastDay = DateTime(DateTime.now().year + 1, 12, 31);
  
  // Map to store recordings by date for the calendar (sample data for demonstration)
  final Map<DateTime, List<String>> _recordingsByDate = {};
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _initializeSampleData(); // This would be replaced with actual data from your backend
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
          _errorMessage = 'Failed to play recording: $error';
        });
      }
    });
    
    // Load the camera if available
    _fetchRecordings();
  }
  
  // Initialize sample recording data for demonstration
  void _initializeSampleData() {
    final now = DateTime.now();
    
    // Create recordings for the past week
    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final day = DateFormat('yyyy-MM-dd').format(date);
      
      // Each day has 2-3 recordings
      _recordingsByDate[date] = [
        'Morning Recording - $day (8:00 AM)',
        'Afternoon Recording - $day (2:30 PM)',
        if (i % 2 == 0) 'Evening Recording - $day (7:15 PM)',
      ];
    }
    
    // Set selected day to today
    _selectedDay = now;
    _updateRecordingsForSelectedDay();
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
  
  // This would typically fetch recordings from a backend based on selected date
  void _fetchRecordings() {
    if (_camera == null) {
      setState(() {
        _availableRecordings = [];
      });
      return;
    }
    
    _updateRecordingsForSelectedDay();
  }
  
  // Update available recordings based on the selected day
  void _updateRecordingsForSelectedDay() {
    if (_selectedDay == null || _camera == null) {
      setState(() {
        _availableRecordings = [];
        _selectedRecording = null;
      });
      return;
    }
    
    // Find recordings for the selected day
    final recordings = _recordingsByDate[DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    )] ?? [];
    
    setState(() {
      _availableRecordings = recordings;
      
      // Auto-select first recording if available
      if (_availableRecordings.isNotEmpty) {
        _selectedRecording = _availableRecordings[0];
        // In a real app, this URL would come from your backend based on the recording
        _loadRecording(_camera!.recordUri);
      } else {
        _selectedRecording = null;
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
  
  // Function to determine if a specific day has recordings
  List<String> _getRecordingsForDay(DateTime day) {
    return _recordingsByDate[DateTime(day.year, day.month, day.day)] ?? [];
  }
  
  // Calculate the marker counts for the calendar
  bool _hasRecordings(DateTime day) {
    return _getRecordingsForDay(day).isNotEmpty;
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
            
            // Right side with calendar, recordings list, and player
            Expanded(
              child: Column(
                children: [
                  // Calendar section
                  Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TableCalendar(
                        firstDay: kFirstDay,
                        lastDay: kLastDay,
                        focusedDay: _focusedDay,
                        calendarFormat: CalendarFormat.month,
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDay, day);
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay; // update focused day
                          });
                          _updateRecordingsForSelectedDay();
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                        eventLoader: _getRecordingsForDay,
                        calendarStyle: CalendarStyle(
                          // Customize the appearance based on app theme
                          todayDecoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: const BoxDecoration(
                            color: AppTheme.primaryOrange,
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: const BoxDecoration(
                            color: AppTheme.primaryOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isNotEmpty) {
                              return Positioned(
                                right: 1,
                                bottom: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(2.0),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryOrange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    events.length.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.0,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                  
                  // Recordings list for selected day
                  if (_availableRecordings.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                'Recordings for ${DateFormat('MMMM d, yyyy').format(_selectedDay!)}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            const Divider(height: 1),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _availableRecordings.length,
                              itemBuilder: (context, index) {
                                final recording = _availableRecordings[index];
                                final isSelected = recording == _selectedRecording;
                                
                                return ListTile(
                                  title: Text(recording),
                                  leading: const Icon(Icons.video_library),
                                  selected: isSelected,
                                  selectedTileColor: AppTheme.primaryOrange.withOpacity(0.1),
                                  onTap: () => _selectRecording(recording),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Player section
                  Expanded(
                    child: _buildPlayer(),
                  ),
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
                ? 'No recordings available for this date'
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
}
