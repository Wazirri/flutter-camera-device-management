import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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
  
  // Animation controller and animations
  late AnimationController _animationController;
  late Animation<Offset> _calendarSlideAnimation;
  late Animation<Offset> _playerSlideAnimation;
  late Animation<double> _fadeInAnimation;
  
  // Recording URLs
  String? _recordingsUrl;
  bool _isLoadingDates = false;
  bool _isLoadingRecordings = false;
  String _loadingError = '';
  Map<DateTime, List<String>> _recordingEvents = {};
  
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
  // İndirme işlevini başlat (Download function)
  // İndirme işlevini başlat (Download function)
  void _downloadRecording(String recording) async {
    if (_selectedDay == null || _camera == null || _recordingsUrl == null) {
      return;
    }
    
    // İndirme için izinleri kontrol et ve iste
    bool hasPermission = await _checkAndRequestPermissions();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İndirme için izinler reddedildi. Ayarlardan izinleri etkinleştirin.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Bildirimi göster (Show notification)
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
    
    try {
      // İndirme URL'sini oluştur
      final dateStr = DateFormat('yyyy_MM_dd').format(_selectedDay!);
      final dayUrl = '$_recordingsUrl$dateStr/';
      final downloadUrl = '$dayUrl$recording';
      
      // HTTP isteği ile dosyayı indir
      final response = await http.get(Uri.parse(downloadUrl));
      
      if (response.statusCode == 200) {
        // İndirilen dosyayı kaydet
        final directory = await _getDownloadDirectory();
        if (directory == null) {
          throw Exception("İndirme dizini bulunamadı");
        }
        
        final filePath = '${directory.path}/$recording';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Başarılı bildirim göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İndirme tamamlandı: $recording'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Aç',
              textColor: Colors.white,
              onPressed: () => _openDownloadedFile(filePath),
            ),
          ),
        );
      } else {
        throw Exception("Dosya indirilemedi: ${response.statusCode}");
      }
    } catch (e) {
      // Hata bildirimini göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İndirme hatası: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      print('İndirme hatası: $e');
    }
  }
  
  // İzinleri kontrol et ve gerekirse iste
  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.storage.status;
      if (status.isGranted) {
        return true;
      }
      
      final result = await Permission.storage.request();
      return result.isGranted;
    }
    
    // Masaüstü platformlarda genellikle izin gerekmez
    return true;
  }
  
  // Dosyayı açma fonksiyonu (platform bağımlı)
  void _openDownloadedFile(String filePath) {
    // Bu kısım uygulamanın desteklediği platformlara göre genişletilebilir
    print('Dosya konumu: $filePath');
    
    // Burada platform tabanlı dosya açma mantığı eklenebilir
    // Örneğin, url_launcher paketi ile açılabilir
  }
  
  // İndirme dizinini alma fonksiyonu (platform bağımlı)
  Future<Directory?> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // Android için indirme klasörünü al
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      // iOS için belge klasörünü kullan
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Masaüstü için belge klasörünü kullan
      return await getDownloadsDirectory();
    }
    // Desteklenmeyen platformlar için null döndür
    return null;
  }
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

  // Calendar recordings helper methods
  List<String> _getRecordingsForDay(DateTime day) {
    return _recordingEvents[day] ?? [];
  }
  
  void _updateRecordingsForSelectedDay() async {
    if (_selectedDay == null || _recordingsUrl == null) {
      return;
    }
    
    setState(() {
      _isLoadingDates = true;
      _availableRecordings = [];
      _loadingError = '';
    });
    
    try {
      // Format date for URL
      final dateStr = DateFormat('yyyy_MM_dd').format(_selectedDay!);
      final url = '$_recordingsUrl$dateStr/';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final html = utf8.decode(response.bodyBytes);
        
        // Parse recording files from HTML
        final recordingRegex = RegExp(r'href="([^"]+\.mkv)"');
        final recordingMatches = recordingRegex.allMatches(html);
        
        final recordings = recordingMatches
            .map((match) => match.group(1)!)
            .toList();
        
        setState(() {
          _availableRecordings = recordings;
          _isLoadingDates = false;
          
          // If we have recordings and none selected, select the first one
          if (recordings.isNotEmpty && _selectedRecording == null) {
            _selectRecording(recordings.first);
          }
        });
      } else {
        setState(() {
          _loadingError = 'Failed to fetch recordings: HTTP ${response.statusCode}';
          _isLoadingDates = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingError = 'Error loading recordings: $e';
        _isLoadingDates = false;
      });
    }
  }
  
  void _selectRecording(String recording) {
    setState(() {
      _selectedRecording = recording;
      _isBuffering = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    // Play the recording
    _loadRecording('$_recordingsUrl${DateFormat('yyyy_MM_dd').format(_selectedDay!)}/$recording');
  }
  
  void _loadRecording(String uri) async {
    print('Loading: $uri');
    
    setState(() {
      _isBuffering = true;
      _hasError = false;
    });
    
    try {
      await _player.open(Media(uri));
      setState(() {
        _isPlaying = true;
        _isBuffering = false;
      });
    } catch (e) {
      print('Error loading recording: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load video: $e';
        _isBuffering = false;
      });
    }
  }
  
  // Toggle fullscreen mode
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }
  
  // İndirme işlevini başlat (Download function)
  void _downloadRecording(String recording) async {
    if (_selectedDay == null || _camera == null || _recordingsUrl == null) {
      return;
    }
    
    // İndirme için izinleri kontrol et ve iste
    bool hasPermission = await _checkAndRequestPermissions();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İndirme için izinler reddedildi. Ayarlardan izinleri etkinleştirin.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Bildirimi göster (Show notification)
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
    
    try {
      // İndirme URL'sini oluştur
      final dateStr = DateFormat('yyyy_MM_dd').format(_selectedDay!);
      final dayUrl = '$_recordingsUrl$dateStr/';
      final downloadUrl = '$dayUrl$recording';
      
      // HTTP isteği ile dosyayı indir
      final response = await http.get(Uri.parse(downloadUrl));
      
      if (response.statusCode == 200) {
        // İndirilen dosyayı kaydet
        final directory = await _getDownloadDirectory();
        if (directory == null) {
          throw Exception("İndirme dizini bulunamadı");
        }
        
        final filePath = '${directory.path}/$recording';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Başarılı bildirim göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İndirme tamamlandı: $recording'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Aç',
              textColor: Colors.white,
              onPressed: () => _openDownloadedFile(filePath),
            ),
          ),
        );
      } else {
        throw Exception("Dosya indirilemedi: ${response.statusCode}");
      }
    } catch (e) {
      // Hata bildirimini göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İndirme hatası: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      print('İndirme hatası: $e');
    }
  }
  
  // İzinleri kontrol et ve gerekirse iste
  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.storage.status;
      if (status.isGranted) {
        return true;
      }
      
      final result = await Permission.storage.request();
      return result.isGranted;
    }
    
    // Masaüstü platformlarda genellikle izin gerekmez
    return true;
  }
  
  // Dosyayı açma fonksiyonu (platform bağımlı)
  void _openDownloadedFile(String filePath) {
    // Bu kısım uygulamanın desteklediği platformlara göre genişletilebilir
    print('Dosya konumu: $filePath');
    
    // Burada platform tabanlı dosya açma mantığı eklenebilir
    // Örneğin, url_launcher paketi ile açılabilir
  }
  
  // İndirme dizinini alma fonksiyonu (platform bağımlı)
  Future<Directory?> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // Android için indirme klasörünü al
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      // iOS için belge klasörünü kullan
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Masaüstü için belge klasörünü kullan
      return await getDownloadsDirectory();
    }
    // Desteklenmeyen platformlar için null döndür
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.darkBackgroundColor,
              AppTheme.darkBackgroundColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (!_isFullScreen)
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                    onPressed: _toggleFullScreen,
                  ),
                  title: Text(_camera != null 
                    ? 'Recordings: ${_camera!.name}' 
                    : 'Camera Recordings',
                    style: TextStyle(color: Colors.white)
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.fullscreen, color: AppTheme.primaryColor),
                      onPressed: _selectedRecording != null ? _toggleFullScreen : null,
                    ),
                  ],
                ),
              
              // Camera Selector (horizontal list)
              if (!_isFullScreen && _availableCameras.length > 1)
                Container(
                  height: 80,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _availableCameras.length,
                    itemBuilder: (context, index) {
                      final camera = _availableCameras[index];
                      final isSelected = index == _selectedCameraIndex;
                      
                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          color: isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.3) 
                            : Colors.grey.shade800.withOpacity(0.3),
                          border: Border.all(
                            color: isSelected 
                              ? AppTheme.primaryColor 
                              : Colors.transparent,
                            width: 2.0,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _selectCamera(index),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                camera.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected 
                                    ? AppTheme.primaryColor 
                                    : Colors.white,
                                  fontWeight: isSelected 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              
              // Main content (with recordings selector and player)
              Expanded(
                child: _isFullScreen
                  ? _buildVideoPlayer()
                  : Row(
                      children: [
                        // Left side - Calendar and Recordings
                        Expanded(
                          flex: ResponsiveHelper.isDesktop(context) ? 1 : 2,
                          child: SlideTransition(
                            position: _calendarSlideAnimation,
                            child: FadeTransition(
                              opacity: _fadeInAnimation,
                              child: Card(
                                margin: const EdgeInsets.all(8.0),
                                color: Colors.grey.shade900.withOpacity(0.7),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    // Calendar
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: TableCalendar(
                                        firstDay: kFirstDay,
                                        lastDay: kLastDay,
                                        focusedDay: _focusedDay,
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
                                          outsideDaysVisible: false,
                                          weekendTextStyle: TextStyle(color: Colors.red[200]),
                                          holidayTextStyle: TextStyle(color: Colors.red[200]),
                                          markersMaxCount: 3,
                                          markersAnchor: 1.7,
                                          markerDecoration: BoxDecoration(
                                            color: AppTheme.accentColor,
                                            shape: BoxShape.circle,
                                          ),
                                          todayDecoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withOpacity(0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          selectedDecoration: BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        headerStyle: HeaderStyle(
                                          formatButtonVisible: false,
                                          titleCentered: true,
                                          titleTextStyle: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                          ),
                                          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white70),
                                          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white70),
                                        ),
                                      ),
                                    ),
                                    
                                    // Loading indicator for dates
                                    if (_isLoadingDates)
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          children: [
                                            CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Loading recordings...',
                                              style: TextStyle(color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    
                                    // Error message
                                    if (_loadingError.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(_loadingError, 
                                            style: TextStyle(color: Colors.white),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    
                                    // Recordings list
                                    if (_availableRecordings.isNotEmpty)
                                      Expanded(
                                        child: FadeTransition(
                                          opacity: _fadeInAnimation,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                  child: Text(
                                                    'Recordings for ${_selectedDay != null ? DateFormat('MMMM d, yyyy').format(_selectedDay!) : "Today"}',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: ListView.builder(
                                                    padding: EdgeInsets.zero,
                                                    itemCount: _availableRecordings.length,
                                                    itemBuilder: (context, index) {
                                                      final recording = _availableRecordings[index];
                                                      final isSelected = recording == _selectedRecording;
                                                      
                                                      return Card(
                                                        margin: const EdgeInsets.only(bottom: 8),
                                                        color: isSelected 
                                                          ? AppTheme.primaryColor.withOpacity(0.2)
                                                          : Colors.grey.shade800.withOpacity(0.5),
                                                        child: ListTile(
                                                          title: Text(recording, style: TextStyle(color: Colors.white)),
                                                          trailing: IconButton(
                                                            icon: Icon(Icons.download, color: Colors.white70),
                                                            onPressed: () => _downloadRecording(recording),
                                                          ),
                                                          selected: isSelected,
                                                          onTap: () => _selectRecording(recording),
                                                        ),
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
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        // Right side - Video player
                        Expanded(
                          flex: ResponsiveHelper.isDesktop(context) ? 2 : 3,
                          child: SlideTransition(
                            position: _playerSlideAnimation,
                            child: FadeTransition(
                              opacity: _fadeInAnimation,
                              child: _buildVideoPlayer(),
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
              
              // Show live view button when no recordings
              if (_availableRecordings.isEmpty && _camera != null && !_isLoadingRecordings)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No recordings available for this date',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          icon: const Icon(Icons.live_tv),
                          label: const Text('Show Live View'),
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
    );
  }
  
  Widget _buildVideoPlayer() {
    return Stack(
      children: [
        // Video Player
        Card(
          margin: _isFullScreen ? EdgeInsets.zero : const EdgeInsets.all(8.0),
          color: Colors.black,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: _isFullScreen ? BorderRadius.zero : BorderRadius.circular(12),
          ),
          child: Video(
            controller: _controller,
            fill: Colors.black,
            controls: false,
          ),
        ),
        
        // Buffering indicator
        if (_isBuffering)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        
        // Error message
        if (_hasError)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_camera != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Live View'),
                      onPressed: () => _loadRecording(_camera!.rtspUri),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  // Video Controls at the bottom
  Widget _buildVideoControls() {
    if (_camera != null)
      return VideoControls(
        player: _player,
        hasFullScreenButton: true,
        onFullScreenToggle: _toggleFullScreen,
      );
    return const SizedBox.shrink();
  }
}
