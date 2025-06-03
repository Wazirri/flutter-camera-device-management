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
import '../providers/camera_devices_provider_optimized.dart';
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

class _RecordViewScreenState extends State<RecordViewScreen> with SingleTickerProviderStateMixin {
  Camera? _camera;
  bool _isFullScreen = false;
  late final Player _player;
  late final VideoController _controller;
  bool _isBuffering = false;
  bool _hasError = false;
  String _errorMessage = '';
  List<Camera> _availableCameras = [];
  List<String> _availableRecordings = [];
  String? _selectedRecording;
  
  // Organized camera data
  final Map<String, List<Camera>> _groupedCameras = {}; // Group name -> cameras
  final List<Camera> _ungroupedCameras = []; // Cameras without groups
  final List<String> _groupNames = []; // List of group names for UI
  final Map<String, bool> _groupExpansionState = {}; // Track which groups are expanded
  
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
  final bool _isLoadingRecordings = false;
  String _loadingError = '';
  final Map<DateTime, List<String>> _recordingEvents = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize player
    _player = Player();
    _controller = VideoController(_player);
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _calendarSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _playerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));
    
    // Start animation
    _animationController.forward();
    
    // Get camera from widget if provided
    _camera = widget.camera;
    if (_camera != null) {
      _initializeCamera();
    }
    
    // Load available cameras from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableCameras();
    });
  }
  
  void _initializeCamera() {
    // Get camera device to fetch recording URL
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    final device = cameraDevicesProvider.getDeviceForCamera(_camera!);
    
    if (device != null) {
      setState(() {
        // Create HTTP URL for recordings
        _recordingsUrl = 'http://${device.ipv4}:8080/Rec/${_camera!.name}/';
        print('Recordings URL: $_recordingsUrl');
        // Update selected day to today
        _selectedDay = DateTime.now();
      });
      
      // Load recordings for today
      _updateRecordingsForSelectedDay();
    } else {
      setState(() {
        _loadingError = 'Device not found for camera: ${_camera!.name}';
      });
    }
  }
  
  void _loadAvailableCameras() {
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    List<Camera> cameras = [];
    
    // Collect all cameras from all devices
    for (final device in cameraDevicesProvider.devices.values) {
      cameras.addAll(device.cameras);
    }
    
    setState(() {
      _availableCameras = cameras;
      
      // Organize cameras by groups
      _organizeCameras();
      
      // If we have cameras but no camera is selected yet, select the first one
      if (cameras.isNotEmpty && _camera == null) {
        _camera = cameras.first;
        _initializeCamera(); // Initialize the first camera automatically
      }
    });
  }

  // Calendar recordings helper methods
  List<String> _getRecordingsForDay(DateTime day) {
    return _recordingEvents[day] ?? [];
  }
  
  void _updateRecordingsForSelectedDay() async {
    if (_selectedDay == null || _recordingsUrl == null) {
      print('Cannot load recordings: selectedDay or recordingsUrl is null');
      return;
    }
    
    setState(() {
      _isLoadingDates = true;
      _availableRecordings = [];
      _loadingError = '';
    });
    
    // Debug logging
    print('Loading recordings for day: $_selectedDay');
    print('Using recordings URL: $_recordingsUrl');
    
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
  
  void _organizeCameras() {
    _groupedCameras.clear();
    _ungroupedCameras.clear();
    _groupNames.clear();
    
    // Track cameras to avoid duplicates in display
    final Set<String> processedCameraIds = {};
    
    // Group cameras
    for (final camera in _availableCameras) {
      if (camera.groups.isNotEmpty) {
        // Camera belongs to one or more groups - add to first group only to avoid duplicates
        final firstGroup = camera.groups.first;
        if (!_groupedCameras.containsKey(firstGroup)) {
          _groupedCameras[firstGroup] = [];
          _groupNames.add(firstGroup);
          // Initialize expansion state (default to collapsed)
          _groupExpansionState[firstGroup] = false;
        }
        
        // Only add camera if we haven't processed it yet
        if (!processedCameraIds.contains(camera.id)) {
          _groupedCameras[firstGroup]!.add(camera);
          processedCameraIds.add(camera.id);
        }
      } else {
        // Camera doesn't belong to any group
        if (!processedCameraIds.contains(camera.id)) {
          _ungroupedCameras.add(camera);
          processedCameraIds.add(camera.id);
        }
      }
    }
    
    // Sort group names for consistent display
    _groupNames.sort();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _player.dispose();
    super.dispose();
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
                  automaticallyImplyLeading: false, // Ana menülerden geliyorsa geri butonu olmayacak
                  leading: Navigator.of(context).canPop() ? IconButton(
                    icon: Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ) : null,
                  title: Text(_camera != null 
                    ? 'Recordings: ${_camera!.name}' 
                    : 'Camera Recordings',
                    style: const TextStyle(color: Colors.white)
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.fullscreen, color: AppTheme.primaryColor),
                      onPressed: _selectedRecording != null ? _toggleFullScreen : null,
                    ),
                  ],
                ),
              
              // Camera Selector (grouped)
              if (!_isFullScreen && _availableCameras.length > 1)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Camera',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Display grouped cameras
                      ...(_groupNames.map((groupName) => _buildCameraGroup(groupName)).toList()),
                      // Display ungrouped cameras
                      if (_ungroupedCameras.isNotEmpty) _buildUngroupedCameras(),
                    ],
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
                                          setState(() {
                                            _focusedDay = focusedDay;
                                          });
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
                                        headerStyle: const HeaderStyle(
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
                                            const Text(
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
                                            style: const TextStyle(color: Colors.white),
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
                                                    style: const TextStyle(
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
                                                          title: Text(recording, style: const TextStyle(color: Colors.white)),
                                                          trailing: IconButton(
                                                            icon: const Icon(Icons.download, color: Colors.white70),
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
            controls: null,
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
          
        // Video Controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _camera != null ? VideoControls(
            player: _player,
            showFullScreenButton: true,
            onFullScreenToggle: _toggleFullScreen,
          ) : const SizedBox.shrink(),
        ),
      ],
    );
  }
  
  Widget _buildCameraGroup(String groupName) {
    final cameras = _groupedCameras[groupName] ?? [];
    final isExpanded = _groupExpansionState[groupName] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        title: Text(
          '$groupName (${cameras.length} cameras)',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          isExpanded ? Icons.expand_less : Icons.expand_more,
          color: AppTheme.primaryColor,
        ),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        iconColor: AppTheme.primaryColor,
        collapsedIconColor: AppTheme.primaryColor,
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _groupExpansionState[groupName] = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: cameras.map((camera) => _buildCameraChip(camera)).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUngroupedCameras() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Individual Cameras',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: _ungroupedCameras.map((camera) => _buildCameraChip(camera)).toList(),
        ),
      ],
    );
  }
  
  Widget _buildCameraChip(Camera camera) {
    final isSelected = _camera?.id == camera.id;
    
    return InkWell(
      onTap: () => _selectCameraByObject(camera),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected 
            ? AppTheme.primaryColor.withOpacity(0.3) 
            : Colors.grey.shade800.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected 
              ? AppTheme.primaryColor 
              : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          camera.name,
          style: TextStyle(
            color: isSelected 
              ? AppTheme.primaryColor 
              : Colors.white,
            fontWeight: isSelected 
              ? FontWeight.bold 
              : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
  
  void _selectCameraByObject(Camera camera) {
    setState(() {
      _camera = camera;
      _selectedRecording = null;
      _recordingsUrl = null;
      _availableRecordings = [];
      _loadingError = '';
    });
    
    _initializeCamera();
  }
}
