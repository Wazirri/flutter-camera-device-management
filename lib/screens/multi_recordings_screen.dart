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
import 'multi_watch_screen.dart';

// Helper class for recording time management
class RecordingTime {
  final Camera camera;
  final String recording;
  final DateTime timestamp;
  
  RecordingTime(this.camera, this.recording, this.timestamp);
}

class MultiRecordingsScreen extends StatefulWidget {
  const MultiRecordingsScreen({Key? key}) : super(key: key);

  @override
  State<MultiRecordingsScreen> createState() => _MultiRecordingsScreenState();
}

class _MultiRecordingsScreenState extends State<MultiRecordingsScreen> with SingleTickerProviderStateMixin {
  // Seçilen kamera ve kayıtlar
  List<Camera> _availableCameras = [];
  List<Camera> _selectedCameras = []; // Kullanıcının seçtiği kameralar
  final Map<Camera, List<String>> _cameraRecordings = {};
  final Map<Camera, String> _cameraErrors = {}; // Her kamera için ayrı hata mesajları
  final Map<Camera, String> _cameraDateFormats = {}; // Her kamera için hangi tarih formatının çalıştığını sakla
  
  // Aktif oynatılan kayıt bilgileri (sadece selection tracking için)
  Camera? _activeCamera;
  String? _activeRecording;
  
  // Takvim değişkenleri
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final kFirstDay = DateTime(DateTime.now().year - 1, 1, 1);
  final kLastDay = DateTime(DateTime.now().year + 1, 12, 31);
  
  // Animasyon controller ve animasyonlar
  late AnimationController _animationController;
  late Animation<Offset> _playerSlideAnimation;
  late Animation<double> _fadeInAnimation;
  
  // Yükleme durumu
  bool _isLoadingRecordings = false;
  String _loadingError = '';
  
  // Çoklu seçim modu
  bool _isMultiSelectionMode = false;
  final Set<String> _selectedForDownload = {};
  
  // Pending camera selection from route arguments
  String? _pendingCameraSelection;
  String? _pendingTargetTime;
  int? _pendingSeekTime; // Seconds to seek when video player opens

  @override
  void initState() {
    super.initState();
    
    // Animasyon controller'ı başlat
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
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
    
    // Animasyonu başlat
    _animationController.forward();
    
    // Kameraları yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('[MultiRecordings] PostFrameCallback - Loading cameras and handling arguments');
      _handleRouteArguments();
      _loadAvailableCameras();
    });
    
    // Bugünü seç
    _selectedDay = DateTime.now();
    print('[MultiRecordings] Selected day initialized: $_selectedDay');
  }

  // Parse timestamp from various filename formats
  DateTime? _parseTimestampFromFilename(String filename) {
    // Remove file extension
    final nameWithoutExt = filename.contains('.') 
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;
    
    try {
      // Format 1: 2025-06-04_07-06-24 (most common)
      if (nameWithoutExt.contains('_')) {
        final parts = nameWithoutExt.split('_');
        if (parts.length >= 2) {
          final datePart = parts[0];
          final timePart = parts[1];
          
          // Parse date part (YYYY-MM-DD or YYYY_MM_DD)
          List<String> dateComponents;
          if (datePart.contains('-')) {
            dateComponents = datePart.split('-');
          } else {
            // Handle compact format like 20250604
            if (datePart.length == 8) {
              dateComponents = [
                datePart.substring(0, 4),  // year
                datePart.substring(4, 6),  // month  
                datePart.substring(6, 8),  // day
              ];
            } else {
              return null;
            }
          }
          
          // Parse time part (HH-MM-SS or HH_MM_SS)
          List<String> timeComponents;
          if (timePart.contains('-')) {
            timeComponents = timePart.split('-');
          } else if (timePart.contains('_')) {
            timeComponents = timePart.split('_');
          } else {
            // Handle compact format like 070624
            if (timePart.length == 6) {
              timeComponents = [
                timePart.substring(0, 2),  // hour
                timePart.substring(2, 4),  // minute
                timePart.substring(4, 6),  // second
              ];
            } else {
              return null;
            }
          }
          
          if (dateComponents.length == 3 && timeComponents.length == 3) {
            final year = int.parse(dateComponents[0]);
            final month = int.parse(dateComponents[1]);
            final day = int.parse(dateComponents[2]);
            final hour = int.parse(timeComponents[0]);
            final minute = int.parse(timeComponents[1]);
            final second = int.parse(timeComponents[2]);
            
            return DateTime(year, month, day, hour, minute, second);
          }
        }
      }
      
      // Format 2: 2025-06-04-07-06-24 (all dashes)
      if (nameWithoutExt.contains('-')) {
        final parts = nameWithoutExt.split('-');
        if (parts.length == 6) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          final hour = int.parse(parts[3]);
          final minute = int.parse(parts[4]);
          final second = int.parse(parts[5]);
          
          return DateTime(year, month, day, hour, minute, second);
        }
      }
      
      // Format 3: 20250604070624 (compact format)
      if (nameWithoutExt.length >= 14 && RegExp(r'^\d+$').hasMatch(nameWithoutExt)) {
        final year = int.parse(nameWithoutExt.substring(0, 4));
        final month = int.parse(nameWithoutExt.substring(4, 6));
        final day = int.parse(nameWithoutExt.substring(6, 8));
        final hour = int.parse(nameWithoutExt.substring(8, 10));
        final minute = int.parse(nameWithoutExt.substring(10, 12));
        final second = int.parse(nameWithoutExt.substring(12, 14));
        
        return DateTime(year, month, day, hour, minute, second);
      }
      
      // Format 4: HH-MM-SS (for m3u8 files that only contain time)
      if (nameWithoutExt.contains('-') && nameWithoutExt.split('-').length == 3) {
        final parts = nameWithoutExt.split('-');
        try {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          final second = int.parse(parts[2]);
          
          // Use the selected day from the calendar as the date
          if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 && second >= 0 && second <= 59) {
            final selectedDate = _selectedDay ?? DateTime.now();
            final timestamp = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, hour, minute, second);
            return timestamp;
          }
        } catch (e) {
          print('[MultiRecordings] Error parsing time-only format for $nameWithoutExt: $e');
        }
      }

      // Format 5: Special MP4 format like 000500__001000 (time range format)
      if (nameWithoutExt.contains('__')) {
        final parts = nameWithoutExt.split('__');
        if (parts.length == 2 && parts[0].length == 6 && parts[1].length == 6) {
          try {
            // Parse start time (HHMMSS format)
            final startTimeStr = parts[0];
            final startHour = int.parse(startTimeStr.substring(0, 2));
            final startMinute = int.parse(startTimeStr.substring(2, 4));
            final startSecond = int.parse(startTimeStr.substring(4, 6));
            
            // Use the selected day from the calendar as the date
            final selectedDate = _selectedDay ?? DateTime.now();
            final timestamp = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 
                                     startHour, startMinute, startSecond);
            
            print('[MultiRecordings] Parsed MP4 time range format: $nameWithoutExt -> $timestamp');
            return timestamp;
          } catch (e) {
            print('[MultiRecordings] Error parsing MP4 time range format for $nameWithoutExt: $e');
          }
        }
      }

    } catch (e) {
      print('[MultiRecordings] Error parsing timestamp from $filename: $e');
    }
    
    return null;
  }
  
  // Handle route arguments passed from Activities screen
  void _handleRouteArguments() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null) {
      print('[MultiRecordings] Route arguments received: $args');
      
      // Handle selectedCamera argument
      final selectedCameraName = args['selectedCamera'] as String?;
      if (selectedCameraName != null) {
        print('[MultiRecordings] Pre-selecting camera: $selectedCameraName');
      }
      
      // Handle selectedDate argument
      final selectedDate = args['selectedDate'] as DateTime?;
      if (selectedDate != null) {
        print('[MultiRecordings] Setting selected date: $selectedDate');
        setState(() {
          _selectedDay = selectedDate;
          _focusedDay = selectedDate;
        });
      }
      
      // Handle targetTime argument - this is the time we want to find a recording for
      final targetTime = args['targetTime'] as String?;
      if (targetTime != null) {
        print('[MultiRecordings] Target time to find recording: $targetTime');
        _pendingTargetTime = targetTime;
      }
      
      // Store camera name to select after cameras are loaded
      if (selectedCameraName != null) {
        _pendingCameraSelection = selectedCameraName;
      }
    } else {
      print('[MultiRecordings] No route arguments found');
    }
  }
  
  void _loadAvailableCameras() {
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    final cameras = cameraDevicesProvider.cameras;
    
    print('[MultiRecordings] Total cameras from provider: ${cameras.length}');
    
    setState(() {
      _availableCameras = cameras.where((camera) => 
        camera.ip.isNotEmpty && 
        camera.recordUri.isNotEmpty
      ).toList();
      
      print('[MultiRecordings] Available cameras after filtering: ${_availableCameras.length}');
      for (final camera in _availableCameras) {
        print('[MultiRecordings] Camera: ${camera.name}, IP: ${camera.ip}, RecordUri: ${camera.recordUri}');
      }
      
      // Handle pending camera selection from route arguments
      if (_pendingCameraSelection != null) {
        print('[MultiRecordings] Looking for camera: "$_pendingCameraSelection"');
        print('[MultiRecordings] Available cameras:');
        for (int i = 0; i < _availableCameras.length; i++) {
          print('[MultiRecordings]   [$i] "${_availableCameras[i].name}"');
        }
        
        final targetCamera = _availableCameras.firstWhere(
          (camera) => camera.name == _pendingCameraSelection,
          orElse: () {
            print('[MultiRecordings] Exact match not found, trying partial matches...');
            
            // Try partial matching strategies
            Camera? partialMatch;
            
            // Strategy 1: Case insensitive exact match
            partialMatch = _availableCameras.cast<Camera?>().firstWhere(
              (camera) => camera!.name.toLowerCase() == _pendingCameraSelection!.toLowerCase(),
              orElse: () => null,
            );
            if (partialMatch != null) {
              print('[MultiRecordings] Found case-insensitive match: "${partialMatch.name}"');
              return partialMatch;
            }
            
            // Strategy 2: Check if camera name contains the selection
            partialMatch = _availableCameras.cast<Camera?>().firstWhere(
              (camera) => camera!.name.toLowerCase().contains(_pendingCameraSelection!.toLowerCase()),
              orElse: () => null,
            );
            if (partialMatch != null) {
              print('[MultiRecordings] Found partial match (contains): "${partialMatch.name}"');
              return partialMatch;
            }
            
            // Strategy 3: Check if selection contains the camera name
            partialMatch = _availableCameras.cast<Camera?>().firstWhere(
              (camera) => _pendingCameraSelection!.toLowerCase().contains(camera!.name.toLowerCase()),
              orElse: () => null,
            );
            if (partialMatch != null) {
              print('[MultiRecordings] Found reverse partial match: "${partialMatch.name}"');
              return partialMatch;
            }
            
            print('[MultiRecordings] No match found, using first camera or dummy');
            return _availableCameras.isNotEmpty ? _availableCameras.first : Camera(
              index: -1, name: '', ip: '', username: '', password: '', brand: '', 
              mediaUri: '', recordUri: '', subUri: '', remoteUri: '', mainSnapShot: '', 
              subSnapShot: '', recordWidth: 0, recordHeight: 0, subWidth: 0, 
              subHeight: 0, connected: false, lastSeenAt: '', recording: false,
            );
          },
        );
        
        if (targetCamera.index != -1) {
          _selectedCameras = [targetCamera];
          _activeCamera = targetCamera;
          print('[MultiRecordings] Pre-selected camera from route arguments: ${targetCamera.name}');
        }
        _pendingCameraSelection = null; // Clear after use
      } 
      // Eğer hiç kamera seçilmemişse, ilk kamerayı seç
      else if (_selectedCameras.isEmpty && _availableCameras.isNotEmpty) {
        _selectedCameras = [_availableCameras.first];
        _activeCamera = _availableCameras.first;
        print('[MultiRecordings] Auto-selected first camera: ${_availableCameras.first.name}');
      } else if (_availableCameras.isEmpty) {
        print('[MultiRecordings] No cameras available!');
      }
    });
    
    // Kayıtları yükle
    _updateRecordingsForSelectedDay();
  }
  
  void _updateRecordingsForSelectedDay() {
    if (_selectedDay == null || _selectedCameras.isEmpty) return;
    
    setState(() {
      _isLoadingRecordings = true;
      _loadingError = '';
      _cameraRecordings.clear();
      _cameraErrors.clear(); // Kamera hatalarını temizle
      _cameraDateFormats.clear(); // Tarih formatlarını temizle
    });
    
    print('[MultiRecordings] Loading recordings for ${_selectedCameras.length} selected cameras');
    
    // Seçili gün için seçili kameraların kayıtlarını yükle
    final selectedDayFormatted = DateFormat('yyyy_MM_dd').format(_selectedDay!);
    final selectedDayFormattedAlt = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final futures = <Future>[];
    
    for (var camera in _selectedCameras) {
      // Kamera device'ını bul
      final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
      
      print('[MultiRecordings] Camera: ${camera.name} (MAC: ${camera.mac}, Index: ${camera.index})');
      print('[MultiRecordings] Camera currentDevice: ${camera.currentDevice?.deviceMac ?? 'NULL'}');
      
      final device = cameraDevicesProvider.getDeviceForCamera(camera);
      
      if (device != null) {
        print('[MultiRecordings] Found device for ${camera.name}: ${device.macAddress} (IP: ${device.ipv4})');
        
        // Kayıt URL'i oluştur
        final recordingsUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/';
        print('[MultiRecordings] Generated URL: $recordingsUrl');
        
        // Kamera için kayıtları yükle
        final future = _loadRecordingsForCamera(camera, recordingsUrl, selectedDayFormatted, selectedDayFormattedAlt);
        futures.add(future);
      } else {
        print('[MultiRecordings] ERROR: No device found for camera ${camera.name}');
      }
    }
    
    // Tüm kameralar için kayıtlar yüklendiğinde
    Future.wait(futures).then((_) {
      setState(() {
        _isLoadingRecordings = false;
      });
      
      print('[MultiRecordings] All recordings loaded. Checking for target time: $_pendingTargetTime');
      
      // If we have a target time, find and play the recording before that time
      if (_pendingTargetTime != null && _activeCamera != null) {
        print('[MultiRecordings] Calling _findAndPlayRecordingBeforeTime with camera: ${_activeCamera!.name}, targetTime: $_pendingTargetTime');
        _findAndPlayRecordingBeforeTime(_activeCamera!, _pendingTargetTime!);
        _pendingTargetTime = null; // Clear after use
      } else {
        print('[MultiRecordings] No target time or active camera. TargetTime: $_pendingTargetTime, ActiveCamera: ${_activeCamera?.name}');
      }
    }).catchError((error) {
      setState(() {
        _isLoadingRecordings = false;
        // Genel hata sadece beklenmedik durumlar için
        print('[MultiRecordings] Unexpected error: $error');
      });
    });
  }
  
  Future<void> _loadRecordingsForCamera(Camera camera, String recordingsUrl, String formattedDate, String formattedDateAlt) async {
    try {
      print('[MultiRecordings] Loading recordings for camera: ${camera.name}');
      print('[MultiRecordings] Recordings URL: $recordingsUrl');
      print('[MultiRecordings] Formatted date: $formattedDate');
      
      final response = await http.get(Uri.parse(recordingsUrl));
      print('[MultiRecordings] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // HTML yanıtı ayrıştır
        final html = response.body;
        
        // Klasör bağlantılarını bul (genellikle tarih klasörleri)
        final dateRegExp = RegExp(r'<a href="([^"]+)/">');
        final dateMatches = dateRegExp.allMatches(html);
        final dates = dateMatches.map((m) => m.group(1)!).toList();
        
        print('[MultiRecordings] Found dates: $dates');
        print('[MultiRecordings] Looking for date: $formattedDate or $formattedDateAlt');
        
        String? foundDate;
        if (dates.contains(formattedDate)) {
          foundDate = formattedDate;
          _cameraDateFormats[camera] = formattedDate; // Çalışan formatı kaydet
        } else if (dates.contains(formattedDateAlt)) {
          foundDate = formattedDateAlt;
          _cameraDateFormats[camera] = formattedDateAlt; // Çalışan formatı kaydet
        }
        
        if (foundDate != null) {
          // Seçili tarih klasörünün içeriğini al
          final dateUrl = '$recordingsUrl$foundDate/';
          print('[MultiRecordings] Loading date folder: $dateUrl');
          final dateResponse = await http.get(Uri.parse(dateUrl));
          
          if (dateResponse.statusCode == 200) {
            // MKV ve M3U8 dosyalarını bul
            final html = utf8.decode(dateResponse.bodyBytes);
            
            // MKV dosyalarını bul
            final mkvRegExp = RegExp(r'<a href="([^"]+\.mkv)"');
            final mkvMatches = mkvRegExp.allMatches(html);
            final mkvRecordings = mkvMatches.map((m) => m.group(1)!).toList();
            
            // M3U8 dosyalarını bul
            final m3u8RegExp = RegExp(r'<a href="([^"]+\.m3u8)"');
            final m3u8Matches = m3u8RegExp.allMatches(html);
            final m3u8Recordings = m3u8Matches.map((m) => m.group(1)!).toList();
            
            // MP4 dosyalarını bul (özel format dahil: 000500__001000.mp4)
            final mp4RegExp = RegExp(r'<a href="([^"]+\.mp4)"');
            final mp4Matches = mp4RegExp.allMatches(html);
            final mp4Recordings = mp4Matches.map((m) => m.group(1)!).toList();
            
            // Tüm kayıtları birleştir
            final allRecordings = [...mkvRecordings, ...m3u8Recordings, ...mp4Recordings];
            
            print('[MultiRecordings] Found ${mkvRecordings.length} MKV, ${m3u8Recordings.length} M3U8, and ${mp4Recordings.length} MP4 recordings for ${camera.name}');
            print('[MultiRecordings] Total recordings: $allRecordings');
            
            if (mounted) {
              setState(() {
                _cameraRecordings[camera] = allRecordings;
              });
            }
          } else {
            print('[MultiRecordings] Failed to load date folder: ${dateResponse.statusCode}');
          }
        } else {
          // Bu tarih için kayıt yok
          print('[MultiRecordings] No recordings found for date $formattedDate or $formattedDateAlt for camera ${camera.name}');
          if (mounted) {
            setState(() {
              _cameraRecordings[camera] = [];
            });
          }
        }
      } else {
        print('[MultiRecordings] Failed to load recordings URL: ${response.statusCode}');
        throw Exception('Failed to load recordings: ${response.statusCode}');
      }
    } catch (e) {
      print('[MultiRecordings] Error loading recordings for ${camera.name}: $e');
      if (mounted) {
        setState(() {
          _cameraErrors[camera] = 'Error loading recordings: $e';
          _cameraRecordings[camera] = [];
        });
      }
    }
  }
  
  void _findAndPlayRecordingBeforeTime(Camera camera, String targetTime) {
    print('[MultiRecordings] Finding recording before time: $targetTime for camera: ${camera.name}');
    
    final recordings = _cameraRecordings[camera];
    if (recordings == null || recordings.isEmpty) {
      print('[MultiRecordings] No recordings found for camera: ${camera.name}');
      return;
    }
    
    // Parse target time to minutes for easier comparison
    final targetParts = targetTime.split(':');
    if (targetParts.length != 3) {
      print('[MultiRecordings] Invalid target time format: $targetTime');
      return;
    }
    
    final targetHour = int.tryParse(targetParts[0]) ?? 0;
    final targetMinute = int.tryParse(targetParts[1]) ?? 0;
    final targetSecond = int.tryParse(targetParts[2]) ?? 0;
    final targetTimeInSeconds = (targetHour * 3600) + (targetMinute * 60) + targetSecond;
    
    print('[MultiRecordings] Target time in seconds: $targetTimeInSeconds');
    
    // Find recordings that start before the target time
    String? bestRecording;
    int bestRecordingTime = -1;
    int seekSeconds = 0; // How many seconds to seek forward in the found recording
    
    for (final recording in recordings) {
      // Extract time from recording filename using our parsing function
      final recordingName = recording.contains('/') ? recording.split('/').last : recording;
      final timestamp = _parseTimestampFromFilename(recordingName);
      
      if (timestamp != null) {
        final hour = timestamp.hour;
        final minute = timestamp.minute;
        final second = timestamp.second;
        final recordingTimeInSeconds = (hour * 3600) + (minute * 60) + second;
        
        print('[MultiRecordings] Recording: $recording, time: $hour:$minute:$second (${recordingTimeInSeconds}s)');
        
        // Check if this recording starts before target time
        if (recordingTimeInSeconds < targetTimeInSeconds) {
          // This recording could contain our target time
          // Check if it's better than our current best match
          if (recordingTimeInSeconds > bestRecordingTime) {
            bestRecording = recording;
            bestRecordingTime = recordingTimeInSeconds;
            // Calculate how far to seek into this recording
            seekSeconds = (targetTimeInSeconds - recordingTimeInSeconds).round();
          }
        }
      } else {
        print('[MultiRecordings] Could not parse time from recording: $recording');
      }
    }
    
    if (bestRecording != null) {
      print('[MultiRecordings] Found best recording: $bestRecording');
      print('[MultiRecordings] Will seek $seekSeconds seconds into the recording');
      
      // Open the video player with the found recording
      // Store seek time for later use when player opens
      _pendingSeekTime = seekSeconds;
      print('[MultiRecordings] Set _pendingSeekTime to: $_pendingSeekTime');
      print('[MultiRecordings] About to call _openVideoPlayerPopup...');
      _openVideoPlayerPopup(camera, bestRecording);
      print('[MultiRecordings] Called _openVideoPlayerPopup');
    } else {
      print('[MultiRecordings] No suitable recording found before target time');
      // If no recording found before target time, just play the first recording
      if (recordings.isNotEmpty) {
        print('[MultiRecordings] Playing first available recording: ${recordings.first}');
        _openVideoPlayerPopup(camera, recordings.first);
      }
    }
  }
  
  void _selectRecording(Camera camera, String recording) {
    setState(() {
      if (_isMultiSelectionMode) {
        // Çoklu seçim modunda
        final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
        final device = cameraDevicesProvider.getDeviceForCamera(camera);
        
        if (device != null) {
          // Include date folder in the download URL
          final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay ?? DateTime.now());
          final completeUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/$dateStr/$recording';
          
          if (_selectedForDownload.contains(completeUrl)) {
            _selectedForDownload.remove(completeUrl);
          } else {
            _selectedForDownload.add(completeUrl);
          }
        }
      } else {
        // Normal modda - Popup player aç
        _openVideoPlayerPopup(camera, recording);
      }
    });
  }
  
  void _openVideoPlayerPopup(Camera camera, String recording) {
    print('[MultiRecordings] _openVideoPlayerPopup called with seekTime: $_pendingSeekTime');
    final device = _getDeviceForCamera(camera);
    
    if (device != null && _selectedDay != null) {
      // Kamera için hangi tarih formatının çalıştığını kontrol et
      final dateFormat = _cameraDateFormats[camera];
      final recordingUrl = dateFormat != null 
          ? 'http://${device.ipv4}:8080/Rec/${camera.name}/$dateFormat/$recording'
          : 'http://${device.ipv4}:8080/Rec/${camera.name}/${DateFormat('yyyy_MM_dd').format(_selectedDay!)}/$recording';
      
      print('[MultiRecordings] Using recording URL: $recordingUrl');
      
      // Store seek time locally before clearing the pending value
      final seekTimeToPass = _pendingSeekTime;
      print('[MultiRecordings] Passing seekTime to popup: $seekTimeToPass');
      
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.black,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  // Header with camera name and close button
                  Container(
                    height: 50,
                    color: AppTheme.primaryBlue,
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(Icons.videocam, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${camera.name} - ${recording.split('/').last}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  // Video player
                  Expanded(
                    child: _VideoPlayerPopup(
                      recordingUrl: recordingUrl,
                      camera: camera,
                      recording: recording,
                      seekTime: seekTimeToPass,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      // Clear pending seek time after dialog is shown
      _pendingSeekTime = null;
    }
  }
  
  CameraDevice? _getDeviceForCamera(Camera camera) {
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    return cameraDevicesProvider.getDeviceForCamera(camera);
  }
  
  void _toggleMultiSelectionMode() {
    setState(() {
      _isMultiSelectionMode = !_isMultiSelectionMode;
      if (!_isMultiSelectionMode) {
        _selectedForDownload.clear();
      }
    });
  }
  
  void _downloadSelectedRecordings() async {
    if (_selectedForDownload.isEmpty) return;
    
    // İzinleri kontrol et
    final permissionStatus = await _checkAndRequestPermissions();
    if (!permissionStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission required to download recordings'))
      );
      return;
    }
    
    // İndirme klasörünü al
    final downloadDir = await _getDownloadDirectory();
    if (downloadDir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get download directory'))
      );
      return;
    }
    
    // İndirme işlemlerini başlat
    for (final recordingUrl in _selectedForDownload) {
      final fileName = recordingUrl.split('/').last;
      final filePath = '${downloadDir.path}/$fileName';
      
      try {
        // İlerleme göstergesi ile indirme işlemini başlat
        final response = await http.get(Uri.parse(recordingUrl));
        
        if (response.statusCode == 200) {
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded: $fileName'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => _openDownloadedFile(filePath),
              ),
            )
          );
        } else {
          throw Exception('Failed to download: ${response.statusCode}');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading $fileName: $e'))
        );
      }
    }
    
    // İndirme tamamlandıktan sonra çoklu seçim modunu kapat
    setState(() {
      _isMultiSelectionMode = false;
      _selectedForDownload.clear();
    });
  }
  
  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid || Platform.isIOS) {
      var status = await Permission.storage.status;
      
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      
      return status.isGranted;
    }
    
    // macOS, Windows ve Linux platformlarında izin gerekmez
    return true;
  }
  
  Future<Directory?> _getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        return await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      } else {
        // macOS, Windows, Linux için - desktop
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          // Desktop için kullanıcıya yer seçtirme seçeneği sun
          final shouldShowPicker = await _showDownloadLocationDialog();
          if (!shouldShowPicker) {
            return await getDownloadsDirectory();
          }
          
          // Kullanıcı kendi yer seçmek istiyorsa Downloads klasörünü kullan
          // TODO: File picker paketi eklendikten sonra kullanıcı seçimi yapılabilir
          return await getDownloadsDirectory();
        }
        return await getDownloadsDirectory();
      }
    } catch (e) {
      print('Error getting download directory: $e');
      return null;
    }
  }
  
  Future<bool> _showDownloadLocationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Download Location'),
          content: const Text('Choose download location:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Downloads Folder'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Choose Location'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
  
  void _openDownloadedFile(String filePath) {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      // Desktop platformlarda dosyayı explorer/finder'da göster
      _showInExplorer(filePath);
    } else {
      // Mobil platformlarda sadece bilgi ver
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File saved at: $filePath'))
      );
    }
  }
  
  void _showInExplorer(String filePath) {
    // Dosyayı explorer/finder'da göstermek için platform-specific komutlar
    try {
      if (Platform.isMacOS) {
        Process.run('open', ['-R', filePath]);
      } else if (Platform.isWindows) {
        Process.run('explorer', ['/select,', filePath]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [File(filePath).parent.path]);
      }
    } catch (e) {
      print('Error opening file in explorer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File saved at: $filePath'))
      );
    }
  }
  
  // Kayıtları ±5dk toleransla grupla
  List<List<RecordingTime>> _groupRecordingsByTime() {
    if (_cameraRecordings.isEmpty) return [];
    
    print('[MultiRecordings] Grouping recordings by time...');
    
    // Tüm kayıtlardan zaman damgalarını çıkar
    final List<RecordingTime> allRecordings = [];
    
    for (final entry in _cameraRecordings.entries) {
      final camera = entry.key;
      final recordings = entry.value;
      
      print('[MultiRecordings] Camera ${camera.name} has ${recordings.length} recordings: $recordings');
      
      for (final recording in recordings) {
        final recordingName = recording.contains('/') ? recording.split('/').last : recording;
        final timestamp = _parseTimestampFromFilename(recordingName);
        
        // Enhanced debugging for file type tracking
        final fileExtension = recordingName.toLowerCase().contains('.mkv') ? 'MKV' : 
                            recordingName.toLowerCase().contains('.m3u8') ? 'M3U8' : 'UNKNOWN';
        
        if (timestamp != null) {
          print('[MultiRecordings] Parsed $recordingName ($fileExtension) -> $timestamp');
          allRecordings.add(RecordingTime(camera, recording, timestamp));
        } else {
          print('[MultiRecordings] ERROR: Could not parse timestamp from $recordingName ($fileExtension)');
        }
      }
    }
    
    print('[MultiRecordings] Total recordings with valid timestamps: ${allRecordings.length}');
    
    // Debug: Count file types in valid recordings
    final mkvCount = allRecordings.where((r) => r.recording.toLowerCase().contains('.mkv')).length;
    final m3u8Count = allRecordings.where((r) => r.recording.toLowerCase().contains('.m3u8')).length;
    print('[MultiRecordings] Valid recordings breakdown: $mkvCount MKV, $m3u8Count M3U8');
    
    if (allRecordings.isEmpty) return [];
    
    // Zaman damgalarına göre sırala
    allRecordings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    print('[MultiRecordings] Sorted recordings:');
    for (final rec in allRecordings) {
      final fileType = rec.recording.toLowerCase().contains('.mkv') ? 'MKV' : 
                      rec.recording.toLowerCase().contains('.m3u8') ? 'M3U8' : 'UNKNOWN';
      print('[MultiRecordings]   ${rec.camera.name}: ${rec.recording} ($fileType) -> ${rec.timestamp}');
    }
    
    // ±5dk toleransla grupla
    final List<List<RecordingTime>> groups = [];
    const Duration tolerance = Duration(minutes: 5);
    
    print('[MultiRecordings] Starting grouping with ${tolerance.inMinutes}min tolerance...');
    
    for (final recording in allRecordings) {
      bool addedToGroup = false;
      
      // Mevcut gruplardan birine eklenebilir mi kontrol et
      for (int i = 0; i < groups.length; i++) {
        final group = groups[i];
        if (group.isNotEmpty) {
          final groupTime = group.first.timestamp;
          final timeDiff = recording.timestamp.difference(groupTime).abs();
          
          if (timeDiff <= tolerance) {
            // Bu gruba ekle, ama aynı kameradan kayıt yoksa
            final hasThisCamera = group.any((r) => r.camera == recording.camera);
            if (!hasThisCamera) {
              print('[MultiRecordings] Adding ${recording.camera.name}:${recording.recording} to group $i (time diff: ${timeDiff.inMinutes}min)');
              group.add(recording);
              addedToGroup = true;
              break;
            } else {
              print('[MultiRecordings] Skipping ${recording.camera.name}:${recording.recording} - camera already in group $i');
            }
          } else {
            print('[MultiRecordings] Time diff too large for ${recording.camera.name}:${recording.recording} vs group $i: ${timeDiff.inMinutes}min > ${tolerance.inMinutes}min');
          }
        }
      }
      
      // Hiçbir gruba eklenemedi, yeni grup oluştur
      if (!addedToGroup) {
        print('[MultiRecordings] Creating new group for ${recording.camera.name}:${recording.recording}');
        groups.add([recording]);
      }
    }
    
    print('[MultiRecordings] Created ${groups.length} groups:');
    for (int i = 0; i < groups.length; i++) {
      final group = groups[i];
      print('[MultiRecordings] Group $i (${group.length} cameras):');
      for (final rec in group) {
        final fileType = rec.recording.toLowerCase().contains('.mkv') ? 'MKV' : 
                        rec.recording.toLowerCase().contains('.m3u8') ? 'M3U8' : 'UNKNOWN';
        print('[MultiRecordings]   ${rec.camera.name}: ${rec.recording} ($fileType)');
      }
    }
    
    // Sadece birden fazla kamerası olan grupları döndür
    final result = groups.where((group) => group.length > 1).toList();
    print('[MultiRecordings] Returning ${result.length} multi-camera groups');
    return result;
  }

  void _openMultiWatchScreen(List<RecordingTime> recordingGroup) {
    final Map<Camera, String> cameraRecordings = {};
    
    for (final recording in recordingGroup) {
      cameraRecordings[recording.camera] = recording.recording;
    }
    
    // Multi Watch sayfasını aç
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiWatchScreen(
          cameraRecordings: cameraRecordings,
          selectedDate: _selectedDay!,
          cameraDateFormats: _cameraDateFormats, // Pass the date formats
        ),
      ),
    );
  }
  
  void _watchClosestRecordings() {
    if (_selectedCameras.isEmpty || _selectedDay == null) return;
    
    // Find closest recordings from each selected camera
    final Map<Camera, String> closestRecordings = {};
    
    for (final camera in _selectedCameras) {
      final recordings = _cameraRecordings[camera];
      if (recordings != null && recordings.isNotEmpty) {
        // For now, just take the first recording from each camera
        // In a more sophisticated implementation, you might want to find recordings
        // that are closest in time to a reference time (like the earliest recording)
        closestRecordings[camera] = recordings.first;
      }
    }
    
    if (closestRecordings.isNotEmpty) {
      // Open Multi Watch screen with closest recordings
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MultiWatchScreen(
            cameraRecordings: closestRecordings,
            selectedDate: _selectedDay!,
            cameraDateFormats: _cameraDateFormats, // Pass the date formats
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No recordings found for selected cameras'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi Recordings'),
        automaticallyImplyLeading: false, // Geri butonunu devre dışı bırak
        actions: [
          // Çoklu seçim modu butonu
          IconButton(
            icon: Icon(_isMultiSelectionMode ? Icons.cancel : Icons.select_all),
            tooltip: _isMultiSelectionMode ? 'Cancel Selection' : 'Multi Select',
            onPressed: _toggleMultiSelectionMode,
          ),
          
          // İndirme butonu (sadece çoklu seçim modunda)
          if (_isMultiSelectionMode)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download Selected',
              onPressed: _selectedForDownload.isNotEmpty ? _downloadSelectedRecordings : null,
            ),
          
          // Yenileme butonu
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Recordings',
            onPressed: _updateRecordingsForSelectedDay,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Dynamic sidebar width based on screen size
            final screenWidth = constraints.maxWidth;
            final sidebarWidth = screenWidth < 800 
                ? screenWidth * 0.35 // 35% for small screens
                : screenWidth < 1200 
                    ? 350.0 // Fixed width for medium screens
                    : screenWidth * 0.25; // 25% for large screens
            
            final sidebarHeight = constraints.maxHeight;
            
            return Row(
              children: [
                // Sol panel - Takvim ve Kamera Seçimi
                Container(
                  width: sidebarWidth,
                  height: sidebarHeight,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Column(
                    children: [
                      // Kompakt Takvim - Dynamic height based on available space
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: sidebarHeight * 0.45, // 45% of sidebar height
                          minHeight: 250, // Minimum height to keep calendar readable
                        ),
                        child: _buildCompactCalendar(),
                      ),
                      
                      // Kamera Seçimi (Gruplu) - Takes remaining space with scrolling
                      Expanded(
                        child: _buildGroupedCameraSelection(),
                      ),
                    ],
                  ),
                ),
                
                // Sağ panel - Sadece Kayıt Listesi
                Expanded(
                  child: SlideTransition(
                    position: _playerSlideAnimation,
                    child: FadeTransition(
                      opacity: _fadeInAnimation,
                      child: _buildRecordingsList(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),    );
  }
  
  Widget _buildRecordingsList() {
    if (_isLoadingRecordings) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading recordings...'),
          ],
        ),
      );
    }
    
    if (_loadingError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _loadingError,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _updateRecordingsForSelectedDay,
            ),
          ],
        ),
      );
    }
    
    // Tüm kameralar için kayıt yoksa
    if (_cameraRecordings.isEmpty ||
        _cameraRecordings.values.every((recordings) => recordings.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            Text(
              _selectedDay != null
                ? 'No recordings available for ${DateFormat('yyyy_MM_dd').format(_selectedDay!)}'
                : 'No recordings available',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Toplu kayıt gruplarını hesapla
    final groups = _groupRecordingsByTime();
    final totalTabs = _cameraRecordings.length + (groups.isNotEmpty ? 1 : 0);
    
    return DefaultTabController(
      length: totalTabs,
      child: Column(
        children: [
          // Tab Bar
          TabBar(
            isScrollable: true,
            tabs: [
              // Toplu İzle tab - EN BAŞTA
              if (groups.isNotEmpty)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_work, size: 16),
                      const SizedBox(width: 4),
                      const Text('Toplu İzle'),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryOrange,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          groups.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Her kamera için tab
              ..._cameraRecordings.keys.map((camera) {
                final recordings = _cameraRecordings[camera] ?? [];
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(camera.name),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          recordings.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          
          // Tab içerikleri
          Expanded(
            child: TabBarView(
              children: [
                // Toplu İzle içeriği - EN BAŞTA
                if (groups.isNotEmpty)
                  _buildGroupRecordingsList(groups),
                // Her kamera için içerik
                ..._cameraRecordings.entries.map((entry) {
                  return _buildCameraRecordingsList(entry.key, entry.value);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraRecordingsList(Camera camera, List<String> recordings) {
    final cameraError = _cameraErrors[camera];
    
    // Hata varsa göster
    if (cameraError != null && cameraError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading recordings for ${camera.name}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                cameraError,
                style: TextStyle(
                  color: Colors.red.withOpacity(0.8),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _updateRecordingsForSelectedDay(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (recordings.isEmpty) {
      return Center(
        child: Text(
          'No recordings available for ${camera.name}',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: recordings.length,
      itemBuilder: (context, index) {
        final recording = recordings[index];
        final recordingName = recording.split('/').last;
        final timestamp = _parseTimestampFromFilename(recordingName);
        
        final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
        final device = cameraDevicesProvider.getDeviceForCamera(camera);
        final recordingUrl = device != null ? 'http://${device.ipv4}:8080/Rec/${camera.name}/$recording' : '';
        
        final isSelected = _isMultiSelectionMode ? 
          _selectedForDownload.contains(recordingUrl) :
          _activeCamera == camera && _activeRecording == recording;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          color: isSelected ? AppTheme.primaryBlue.withOpacity(0.2) : null,
          child: ListTile(
            leading: Icon(
              isSelected && _isMultiSelectionMode ? Icons.check_circle : 
              recordingName.toLowerCase().endsWith('.m3u8') ? Icons.playlist_play : Icons.videocam,
              color: isSelected ? AppTheme.primaryBlue : null,
            ),
            title: Row(
              children: [
                Expanded(child: Text(recordingName)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: recordingName.toLowerCase().endsWith('.m3u8') 
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    recordingName.toLowerCase().endsWith('.m3u8') ? 'M3U8' : 'MKV',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: recordingName.toLowerCase().endsWith('.m3u8') 
                          ? Colors.orange
                          : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: timestamp != null
              ? Text(DateFormat('HH:mm:ss').format(timestamp))
              : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: _isMultiSelectionMode ? null : () => _selectRecording(camera, recording),
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _downloadSingleRecording(camera, recording, recordingUrl),
                ),
              ],
            ),
            onTap: () => _selectRecording(camera, recording),
          ),
        );
      },
    );
  }

  Widget _buildGroupRecordingsList(List<List<RecordingTime>> groups) {
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final groupTime = group.isNotEmpty 
          ? DateFormat('HH:mm:ss').format(group.first.timestamp)
          : '';
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: ListTile(
            leading: const Icon(Icons.play_circle_fill, color: AppTheme.primaryOrange),
            title: Text('Grup ${index + 1} - $groupTime'),
            subtitle: Text(
              '${group.length} kamera: ${group.map((r) => r.camera.name).join(', ')}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _openMultiWatchScreen(group),
          ),
        );
      },
    );
  }

  void _downloadSingleRecording(Camera camera, String recording, String recordingUrl) async {
    if (_isMultiSelectionMode) {
      _selectRecording(camera, recording);
      return;
    }
    
    // Tekli indirme işlemi
    final permissionStatus = await _checkAndRequestPermissions();
    if (!permissionStatus) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission required to download recordings'))
      );
      return;
    }
    
    final downloadDir = await _getDownloadDirectory();
    if (downloadDir == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get download directory'))
      );
      return;
    }
    
    final fileName = recording.split('/').last;
    final filePath = '${downloadDir.path}/$fileName';
    
    try {
      final response = await http.get(Uri.parse(recordingUrl));
      
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: $fileName'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => _openDownloadedFile(filePath),
            ),
          )
        );
      } else {
        throw Exception('Failed to download: ${response.statusCode}');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading $fileName: $e'))
      );
    }
  }
  
  Widget _buildCompactCalendar() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Date',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            // Dynamic calendar with responsive sizing
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate optimal sizes based on available space
                final availableHeight = constraints.maxHeight - 30; // Reserve space for title
                final cellSize = (constraints.maxWidth - 32) / 7; // 7 days per week, account for padding
                const headerHeight = 40.0;
                const daysOfWeekHeight = 20.0;
                final calendarBodyHeight = cellSize * 6; // 6 weeks max
                
                // Adjust sizes if calendar would be too tall
                final totalNeededHeight = headerHeight + daysOfWeekHeight + calendarBodyHeight;
                final scaleFactor = totalNeededHeight > availableHeight 
                    ? availableHeight / totalNeededHeight 
                    : 1.0;
                
                final fontSize = (10 * scaleFactor).clamp(8.0, 12.0);
                final headerFontSize = (16 * scaleFactor).clamp(12.0, 18.0);
                final cellPadding = (2 * scaleFactor).clamp(1.0, 3.0);
                final cellMargin = (1 * scaleFactor).clamp(0.5, 2.0);
                
                return Container(
                  constraints: BoxConstraints(
                    maxHeight: availableHeight,
                  ),
                  child: SingleChildScrollView(
                    child: TableCalendar(
                      firstDay: kFirstDay,
                      lastDay: kLastDay,
                      focusedDay: _focusedDay,
                      calendarFormat: CalendarFormat.month,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(fontSize: headerFontSize),
                        leftChevronPadding: EdgeInsets.zero,
                        rightChevronPadding: EdgeInsets.zero,
                        headerPadding: EdgeInsets.symmetric(vertical: 4 * scaleFactor),
                        headerMargin: EdgeInsets.only(bottom: 4 * scaleFactor),
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        cellMargin: EdgeInsets.all(cellMargin),
                        cellPadding: EdgeInsets.all(cellPadding),
                        defaultTextStyle: TextStyle(fontSize: fontSize),
                        weekendTextStyle: TextStyle(fontSize: fontSize),
                        selectedTextStyle: TextStyle(
                          fontSize: fontSize, 
                          color: Colors.white, 
                          fontWeight: FontWeight.bold
                        ),
                        todayTextStyle: TextStyle(
                          fontSize: fontSize, 
                          color: Colors.white, 
                          fontWeight: FontWeight.bold
                        ),
                        todayDecoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: const BoxDecoration(
                          color: AppTheme.primaryOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(fontSize: fontSize * 0.9, fontWeight: FontWeight.w500),
                        weekendStyle: TextStyle(
                          fontSize: fontSize * 0.9, 
                          fontWeight: FontWeight.w500, 
                          color: Colors.red
                        ),
                      ),
                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDay, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        _updateRecordingsForSelectedDay();
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedCameraSelection() {
    final provider = Provider.of<CameraDevicesProviderOptimized>(context);
    final cameraGroups = provider.cameraGroupsList;
    
    print('[MultiRecordings] Camera groups count: ${cameraGroups.length}');
    print('[MultiRecordings] Available cameras count: ${_availableCameras.length}');
    print('[MultiRecordings] Selected cameras count: ${_selectedCameras.length}');
    
    // Get ungrouped cameras
    final groupedCameraNames = <String>{};
    for (final group in cameraGroups) {
      final camerasInGroup = provider.getCamerasInGroup(group.name);
      for (final camera in camerasInGroup) {
        groupedCameraNames.add(camera.name);
      }
    }
    
    final ungroupedCameras = _availableCameras.where((camera) => 
      !groupedCameraNames.contains(camera.name)
    ).toList();
    
    print('[MultiRecordings] Ungrouped cameras count: ${ungroupedCameras.length}');
    
    // If no groups exist, show ungrouped cameras only
    if (cameraGroups.isEmpty) {
      print('[MultiRecordings] No camera groups found, using ungrouped cameras');
      return _buildUngroupedCameraSelection();
    }
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Camera Groups',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_selectedCameras.length} selected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // Select All / Clear All buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.select_all, size: 16),
                    label: const Text('Select All'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedCameras.clear();
                        // Add all grouped cameras
                        for (final group in cameraGroups) {
                          final camerasInGroup = provider.getCamerasInGroup(group.name);
                          _selectedCameras.addAll(camerasInGroup);
                        }
                        // Add all ungrouped cameras
                        _selectedCameras.addAll(ungroupedCameras);
                      });
                      _updateRecordingsForSelectedDay();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear All'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedCameras.clear();
                        _cameraRecordings.clear();
                        _cameraErrors.clear();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Toplu İzle button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_circle_fill, size: 18),
                label: const Text('Toplu İzle (Closest Times)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _selectedCameras.isEmpty ? null : () {
                  _watchClosestRecordings();
                },
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Camera groups and ungrouped cameras list
          Expanded(
            child: ListView(
              children: [
                // Camera groups
                ...cameraGroups.map((group) {
                  final camerasInGroup = provider.getCamerasInGroup(group.name);
                  final selectedInGroup = camerasInGroup.where((c) => _selectedCameras.contains(c)).length;
                  
                  return ExpansionTile(
                    leading: Icon(
                      Icons.videocam_outlined,
                      color: selectedInGroup > 0 ? AppTheme.primaryBlue : null,
                    ),
                    title: Text(
                      group.name,
                      style: TextStyle(
                        fontWeight: selectedInGroup > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text('$selectedInGroup/${camerasInGroup.length} cameras selected'),
                    children: [
                      ...camerasInGroup.map((camera) {
                        final isSelected = _selectedCameras.contains(camera);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 50, right: 16),
                          title: Text(
                            camera.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            'IP: ${camera.ip}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                if (!_selectedCameras.contains(camera)) {
                                  _selectedCameras.add(camera);
                                }
                              } else {
                                _selectedCameras.remove(camera);
                                _cameraRecordings.remove(camera);
                                _cameraErrors.remove(camera);
                              }
                            });
                            _updateRecordingsForSelectedDay();
                          },
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
                
                // Ungrouped cameras section (if any)
                if (ungroupedCameras.isNotEmpty) ...[
                  const Divider(),
                  ExpansionTile(
                    leading: Icon(
                      Icons.videocam_off_outlined,
                      color: ungroupedCameras.any((c) => _selectedCameras.contains(c)) ? AppTheme.primaryOrange : null,
                    ),
                    title: Text(
                      'Ungrouped Cameras',
                      style: TextStyle(
                        fontWeight: ungroupedCameras.any((c) => _selectedCameras.contains(c)) ? FontWeight.bold : FontWeight.normal,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    subtitle: Text('${ungroupedCameras.where((c) => _selectedCameras.contains(c)).length}/${ungroupedCameras.length} cameras selected'),
                    children: [
                      ...ungroupedCameras.map((camera) {
                        final isSelected = _selectedCameras.contains(camera);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 50, right: 16),
                          title: Text(
                            camera.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            'IP: ${camera.ip}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                if (!_selectedCameras.contains(camera)) {
                                  _selectedCameras.add(camera);
                                }
                              } else {
                                _selectedCameras.remove(camera);
                                _cameraRecordings.remove(camera);
                                _cameraErrors.remove(camera);
                              }
                            });
                            _updateRecordingsForSelectedDay();
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUngroupedCameraSelection() {
    print('[MultiRecordings] Building ungrouped camera selection with ${_availableCameras.length} cameras');
    
    if (_availableCameras.isEmpty) {
      print('[MultiRecordings] No cameras available, showing empty state');
      return const Card(
        margin: EdgeInsets.all(8.0),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text('No cameras available'),
          ),
        ),
      );
    }
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Cameras',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_selectedCameras.length}/${_availableCameras.length} selected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          
          // Select All / Clear All buttons  
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.select_all, size: 16),
                    label: const Text('Select All'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedCameras = List.from(_availableCameras);
                      });
                      _updateRecordingsForSelectedDay();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear All'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedCameras.clear();
                        _cameraRecordings.clear();
                        _cameraErrors.clear();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Toplu İzle button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_circle_fill, size: 18),
                label: const Text('Toplu İzle (Closest Times)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _selectedCameras.isEmpty ? null : () {
                  _watchClosestRecordings();
                },
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Camera list
          Expanded(
            child: ListView.builder(
              itemCount: _availableCameras.length,
              itemBuilder: (context, index) {
                final camera = _availableCameras[index];
                final isSelected = _selectedCameras.contains(camera);
                return CheckboxListTile(
                  dense: true,
                  title: Text(
                    camera.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    'IP: ${camera.ip}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        if (!_selectedCameras.contains(camera)) {
                          _selectedCameras.add(camera);
                        }
                      } else {
                        _selectedCameras.remove(camera);
                        _cameraRecordings.remove(camera);
                        _cameraErrors.remove(camera);
                      }
                    });
                    _updateRecordingsForSelectedDay();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Popup Video Player Widget
class _VideoPlayerPopup extends StatefulWidget {
  final String recordingUrl;
  final Camera camera;
  final String recording;
  final int? seekTime; // Seconds to seek to when video starts

  const _VideoPlayerPopup({
    required this.recordingUrl,
    required this.camera,
    required this.recording,
    this.seekTime,
  });

  @override
  State<_VideoPlayerPopup> createState() => _VideoPlayerPopupState();
}

class _VideoPlayerPopupState extends State<_VideoPlayerPopup> {
  late final Player _popupPlayer;
  late final VideoController _popupController;
  bool _isBuffering = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    
    print('[VideoPlayerPopup] initState called with seekTime: ${widget.seekTime}');
    
    // Create separate player for popup
    _popupPlayer = Player();
    _popupController = VideoController(_popupPlayer);
    
    // Setup error listener
    _popupPlayer.stream.error.listen((error) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = "Error playing video: ${error.toString()}";
        });
      }
    });
    
    // Setup buffering listener
    _popupPlayer.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          _isBuffering = buffering;
        });
      }
    });
    
    // Load and play the video
    _loadVideo();
  }

  void _loadVideo() {
    try {
      _popupPlayer.open(Media(widget.recordingUrl), play: true);
      
      // If we have a seek time, wait for the video to be ready and then seek
      if (widget.seekTime != null && widget.seekTime! > 0) {
        print('[VideoPlayerPopup] Will seek to ${widget.seekTime} seconds');
        
        // Listen for when the video is ready to seek
        _popupPlayer.stream.duration.listen((duration) {
          if (duration != Duration.zero && mounted) {
            // Video is ready, now we can seek
            final seekDuration = Duration(seconds: widget.seekTime!);
            print('[VideoPlayerPopup] Video ready, seeking to: $seekDuration');
            
            // Delay the seek slightly to ensure video is fully loaded
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _popupPlayer.seek(seekDuration);
                print('[VideoPlayerPopup] Seek completed to: $seekDuration');
              }
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error loading recording: $e';
      });
    }
  }

  @override
  void dispose() {
    _popupPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                style: TextStyle(
                  color: Colors.red.withOpacity(0.8),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _errorMessage = '';
                });
                _loadVideo();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Video widget without built-in controls
        Video(
          controller: _popupController,
          fit: BoxFit.contain,
          controls: null, // Disable built-in controls
        ),
        
        // Loading indicator
        if (_isBuffering)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange),
            ),
          ),
        
        // Video controls overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: VideoControls(
            player: _popupPlayer,
            showFullScreenButton: true,
            onFullScreenToggle: () {
              // Close popup instead of fullscreen toggle
              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }
}