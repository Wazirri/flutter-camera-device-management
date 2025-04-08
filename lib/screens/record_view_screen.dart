import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';
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
  List<String> _availableRecordings = [];
  String? _selectedRecording;
  
  // Calendar related variables
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final kFirstDay = DateTime(DateTime.now().year - 1, 1, 1);
  final kLastDay = DateTime(DateTime.now().year + 1, 12, 31);
  
  // Map to store recordings by date for the calendar
  final Map<DateTime, List<String>> _recordingsByDate = {};
  
  // API URL for recordings
  String? _recordingsUrl;
  
  // Hata durumlarını izlemek için
  bool _isLoadingDates = false;
  bool _isLoadingRecordings = false;
  String _loadingError = '';
  
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
    _initializeData();
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
          _errorMessage = 'Failed to play recording: $error';
        });
      }
    });
    
    // Load the camera if available
    _fetchRecordings();
  }
  
  // Initialize data with current date selection
  void _initializeData() {
    // Set selected day to today 
    _selectedDay = DateTime.now();
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
  
  // Fetch available recording dates for the selected camera
  void _fetchRecordings() async {
    if (_camera == null) {
      setState(() {
        _availableRecordings = [];
        _recordingsByDate.clear();
      });
      return;
    }
    
    setState(() {
      _isLoadingDates = true;
      _loadingError = '';
    });
    
    try {
      // Get the parent device of this camera
      final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
      final parentDevice = cameraProvider.getDeviceForCamera(_camera!);
      
      if (parentDevice == null) {
        throw Exception('Could not find parent device for this camera');
      }
      
      // Construct the recordings base URL using the device IP (not camera IP)
      final deviceIp = parentDevice.ipv4;
      if (deviceIp.isEmpty) {
        throw Exception('Device IP is not available');
      }
      
      _recordingsUrl = 'http://$deviceIp:8080/Rec/${_camera!.name}/';
      // Fetch the recordings directory listing
      final response = await http.get(Uri.parse(_recordingsUrl!));
      
      if (response.statusCode == 200) {
        // Parse the directory listing (this is simplified and would need to be adjusted 
        // based on actual server response format)
        
        // For demo purposes, let's assume response contains a basic HTML directory listing
        // In reality, you might need to use a regex or HTML parser to extract folders
        final dateRegex = RegExp(r'href="(\d{4}_\d{2}_\d{2})/"');
        final matches = dateRegex.allMatches(response.body);
        
        final Map<DateTime, List<String>> newRecordings = {};
        
        // Extract dates
        for (final match in matches) {
          final dateStr = match.group(1)!;
          final dateParts = dateStr.split('_');
          if (dateParts.length == 3) {
            final year = int.parse(dateParts[0]);
            final month = int.parse(dateParts[1]);
            final day = int.parse(dateParts[2]);
            
            final date = DateTime(year, month, day);
            // Add the date to map with empty recordings list, will be populated when selected
            newRecordings[date] = [];
          }
        }
        
        if (mounted) {
          setState(() {
            _recordingsByDate.clear();
            _recordingsByDate.addAll(newRecordings);
            _isLoadingDates = false;
          });
        }
        
        // Update recordings for selected day
        _updateRecordingsForSelectedDay();
      } else {
        throw Exception('Failed to load recordings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching recordings: $e');
      if (mounted) {
        setState(() {
          _isLoadingDates = false;
          _loadingError = 'Failed to load recordings: $e';
        });
      }
    }
  }
  
  void _updateRecordingsForSelectedDay() async {
    if (_selectedDay == null || _camera == null || _recordingsUrl == null) {
      setState(() {
        _availableRecordings = [];
        _selectedRecording = null;
        _isLoadingRecordings = false;
      });
      return;
    }
    
    // Format date for URL
    final dateStr = DateFormat('yyyy_MM_dd').format(_selectedDay!);
    final dayUrl = '$_recordingsUrl$dateStr/';
    
    setState(() {
      _isLoadingRecordings = true;
      _loadingError = '';
    });
    
    try {
      // Fetch recordings for the selected day
      final response = await http.get(Uri.parse(dayUrl));
      
      if (response.statusCode == 200) {
        // Reset animations for new data
        _animationController.reset();
        
        // Parse recording files from the response
        // This is simplified - adjust according to actual server response format
        final recordingRegex = RegExp(r'href="([^"]+\.mkv)"');
        final matches = recordingRegex.allMatches(response.body);
        
        final List<String> recordings = [];
        
        for (final match in matches) {
          final fileName = match.group(1)!;
          recordings.add(fileName);
        }
        
        if (mounted) {
          setState(() {
            _availableRecordings = recordings;
            _isLoadingRecordings = false;
            
            // Auto-select first recording if available
            if (_availableRecordings.isNotEmpty) {
              _selectedRecording = _availableRecordings[0];
              _loadRecording('$dayUrl${_selectedRecording!}');
            } else {
              _selectedRecording = null;
              // Show live view if no recordings
              if (_camera != null) {
                _loadRecording(_camera!.rtspUri);
              }
            }
          });
        }
        
        // Start animations for updated data
        _animationController.forward();
      } else {
        throw Exception('Failed to load recordings for selected day: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching recordings for day: $e');
      if (mounted) {
        setState(() {
          _isLoadingRecordings = false;
          _loadingError = 'Failed to load recordings for selected day: $e';
          _availableRecordings = [];
          
          // Show live view if fetching recordings fails
          if (_camera != null) {
            _loadRecording(_camera!.rtspUri);
          }
        });
      }
    }
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
    if (index >= 0 && index < _availableCameras.length && index != _selectedCameraIndex) {
      // Reset animations for transition
      _animationController.reset();
      
      setState(() {
        _selectedCameraIndex = index;
        _camera = _availableCameras[index];
        _selectedRecording = null;
      });
      
      // Fetch recordings for the newly selected camera
      _fetchRecordings();
      
      // Start animations for the new data
      _animationController.forward();
    }
  }
  
  void _selectRecording(String recording) {
    if (recording == _selectedRecording) return;
    
    // Create a short animation effect for selection change
    _animationController.reverse().then((_) {
      setState(() {
        _selectedRecording = recording;
      });
      
      // Format date for URL
      final dateStr = DateFormat('yyyy_MM_dd').format(_selectedDay!);
      final dayUrl = '$_recordingsUrl$dateStr/';
      
      // Load the selected recording
      _loadRecording('$dayUrl$recording');
      
      _animationController.forward();
    });
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
  // İndirme işlevini başlat
  void _downloadRecording(String recording) async {
    if (_selectedDay == null || _camera == null || _recordingsUrl == null) {
      return;
    }
    
    // Bildirimi göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('İndiriliyor: $recording'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Tamam',
          onPressed: () {},
        ),
      ),
    );
    
    // İndirme URL'sini oluştur
    final dateStr = DateFormat('yyyy_MM_dd').format(_selectedDay!);
    final dayUrl = '$_recordingsUrl$dateStr/';
    final downloadUrl = '$dayUrl$recording';
    
    // Bu URL'yi paylaşmak veya tarayıcıda açmak için ilgili platform API'lerini kullanabilirsiniz
    // Örneğin: url_launcher paketi ile tarayıcıda açma
    print('İndirme URL: $downloadUrl');
  }
  
  // İndirme işlevini başlat
  void _downloadRecording(String recording) async {
    if (_selectedDay == null || _camera == null || _recordingsUrl == null) {
      return;
    }
    
    // Bildirimi göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('İndiriliyor: $recording'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Tamam',
          onPressed: () {},
        ),
      ),
    );
    
    // İndirme URL'sini oluştur
    final dateStr = DateFormat('yyyy_MM_dd').format(_selectedDay!);
    final dayUrl = '$_recordingsUrl$dateStr/';
    final downloadUrl = '$dayUrl$recording';
    
    // Bu URL'yi paylaşmak veya tarayıcıda açmak için ilgili platform API'lerini kullanabilirsiniz
    // Örneğin: url_launcher paketi ile tarayıcıda açma
    print('İndirme URL: $downloadUrl');
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
            onPressed: _selectedRecording != null ? _toggleFullScreen : null,
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
            
            // Right side with calendar, recordings list, and player
            Expanded(
              child: Column(
                children: [
                  // Calendar section with slide-in animation
                  SlideTransition(
                    position: _calendarSlideAnimation,
                    child: FadeTransition(
                      opacity: _fadeInAnimation,
                      child: Card(
                        margin: const EdgeInsets.all(8.0),
                        elevation: 4,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                              markersMaxCount: 3,
                              markersAnchor: 0.7,
                              outsideDaysVisible: false,
                              weekendTextStyle: const TextStyle(color: Colors.red),
                              holidayTextStyle: const TextStyle(color: Colors.blue),
                            ),
                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, date, events) {
                                if (events.isNotEmpty) {
                                  return Positioned(
                                    right: 1,
                                    bottom: 1,
                                    child: _buildMarker(events.length),
                                  );
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Loading indicator for dates
                  if (_isLoadingDates)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(strokeWidth: 2),
                          const SizedBox(width: 12),
                          Text('Loading recording dates...', 
                            style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  
                  // Error message
                  if (_loadingError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(_loadingError, 
                                  style: TextStyle(color: Colors.red.shade900)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // Recordings list for selected day
                  if (_availableRecordings.isNotEmpty)
                    FadeTransition(
                      opacity: _fadeInAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  'Recordings for ${_selectedDay != null ? DateFormat('MMMM d, yyyy').format(_selectedDay!) : "Today"}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              const Divider(height: 1),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _availableRecordings.length,
                                  itemBuilder: (context, index) {
                                    final recording = _availableRecordings[index];
                                    final isSelected = recording == _selectedRecording;
                                    
                                    return ListTile(
                                      title: Text(recording),
                                      selected: isSelected,
                                      leading: Icon(
                                        Icons.video_library,
                                        color: isSelected ? AppTheme.primaryOrange : null,
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.download),
                                        tooltip: 'İndir',
                                        onPressed: () => _downloadRecording(recording),
                                      ),
                                      selectedTileColor: AppTheme.primaryOrange.withOpacity(0.1),
                                      onTap: () => _selectRecording(recording),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                  // Loading indicator for recordings
                  if (_isLoadingRecordings)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(strokeWidth: 2),
                          const SizedBox(width: 12),
                          Text('Loading recordings...', 
                            style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  
                  // Video player with controls
                  Expanded(
                    child: SlideTransition(
                      position: _playerSlideAnimation,
                      child: FadeTransition(
                        opacity: _fadeInAnimation,
                        child: _buildPlayer(),
                      ),
                    ),
                  ),
                  
                  // Controls for when no recordings are available
                  if (_availableRecordings.isEmpty && _camera != null && !_isLoadingRecordings)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Card(
                        elevation: 2,
                        shadowColor: Colors.black12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text('No recordings available for selected date'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.live_tv),
                                label: const Text('Watch Live Stream'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryOrange,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _loadRecording(_camera!.rtspUri),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build the player section
  Widget _buildPlayer() {
    return Column(
      children: [
        // Expanded video section
        Expanded(
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video player
                Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Video(
                      controller: _controller,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                
                // Loading indicator
                if (_isBuffering)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                
                // Error display
                if (_hasError)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
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
                          if (_camera != null)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.live_tv),
                              label: const Text('Switch to Live View'),
                              onPressed: () => _loadRecording(_camera!.rtspUri),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Video controls at the bottom
        if (_camera != null)
          VideoControls(
            player: _player,
            showFullScreenButton: true,
            onFullScreenToggle: _toggleFullScreen,
          ),
      ],
    );
  }
  
  // Build a marker for the calendar to show recording count
  Widget _buildMarker(int count) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryOrange,
      ),
      width: 12,
      height: 12,
      child: Center(
        child: count > 1 
          ? Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
      ),
    );
  }
}
