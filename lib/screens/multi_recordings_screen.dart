import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';
import 'multi_watch_screen.dart';

// Helper class for recording time management
class RecordingTime {
  final Camera camera;
  final String recording;
  final DateTime timestamp;
  final String? deviceMac; // For multi-device cameras
  
  RecordingTime(this.camera, this.recording, this.timestamp, {this.deviceMac});
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
  final Map<Camera, String> _cameraSelectedDevice = {}; // Her kamera için seçilen cihaz MAC adresi
  
  // Multi-device recordings: Camera -> DeviceMAC -> List of recordings
  final Map<Camera, Map<String, List<String>>> _cameraDeviceRecordings = {};
  final Map<Camera, Map<String, String>> _cameraDeviceErrors = {}; // Camera -> DeviceMAC -> error message
  final Map<Camera, Map<String, String>> _cameraDeviceDateFormats = {}; // Camera -> DeviceMAC -> date format
  
  // Aktif oynatılan kayıt bilgileri (sadece selection tracking için)
  Camera? _activeCamera;
  String? _activeRecording;
  String? _activeDeviceMac; // Active device for multi-device cameras
  
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
  
  // Timer for periodic refresh
  Timer? _refreshTimer;

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
    
    // Her 1 dakikada bir yeni kayıtları kontrol et
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkForNewRecordings();
    });
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
              subHeight: 0, connected: false, lastSeenAt: '',
            );
          },
        );
        
        if (targetCamera.index != -1) {
          // Use _selectCamera to handle multi-device selection
          _selectCameraWithDeviceChoice(targetCamera);
          print('[MultiRecordings] Pre-selected camera from route arguments: ${targetCamera.name}');
        }
        _pendingCameraSelection = null; // Clear after use
      } 
      // Eğer hiç kamera seçilmemişse, ilk kamerayı seç
      else if (_selectedCameras.isEmpty && _availableCameras.isNotEmpty) {
        // Use _selectCamera to handle multi-device selection
        _selectCameraWithDeviceChoice(_availableCameras.first);
        print('[MultiRecordings] Auto-selected first camera: ${_availableCameras.first.name}');
      } else if (_availableCameras.isEmpty) {
        print('[MultiRecordings] No cameras available!');
      }
    });
  }
  
  // Select camera and show device dialog if needed, then update recordings
  Future<void> _selectCameraWithDeviceChoice(Camera camera) async {
    if (camera.currentDevices.length > 1) {
      // Show device selection dialog
      final selectedDevice = await _showDeviceSelectionDialog(camera);
      if (selectedDevice != null) {
        _cameraSelectedDevice[camera] = selectedDevice;
        setState(() {
          _selectedCameras = [camera];
          _activeCamera = camera;
        });
        _updateRecordingsForSelectedDay();
      } else {
        // User cancelled, still add camera with first device
        _cameraSelectedDevice[camera] = camera.currentDevices.keys.first;
        setState(() {
          _selectedCameras = [camera];
          _activeCamera = camera;
        });
        _updateRecordingsForSelectedDay();
      }
    } else if (camera.currentDevices.isNotEmpty) {
      _cameraSelectedDevice[camera] = camera.currentDevices.keys.first;
      setState(() {
        _selectedCameras = [camera];
        _activeCamera = camera;
      });
      _updateRecordingsForSelectedDay();
    } else {
      setState(() {
        _selectedCameras = [camera];
        _activeCamera = camera;
      });
      _updateRecordingsForSelectedDay();
    }
  }
  
  // Show device selection dialog for cameras on multiple devices
  Future<String?> _showDeviceSelectionDialog(Camera camera) async {
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.devices, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${camera.name} - Cihaz Seçin',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bu kamera ${camera.currentDevices.length} farklı cihazda bulunuyor. Kayıtları hangi cihazdan yüklemek istiyorsunuz?',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ...camera.currentDevices.entries.map((entry) {
                final deviceMac = entry.key;
                final deviceInfo = entry.value;
                
                // Find device details from provider
                CameraDevice? device;
                try {
                  device = cameraDevicesProvider.devices.values.firstWhere(
                    (d) => d.macAddress == deviceMac || d.macKey == deviceMac,
                  );
                } catch (e) {
                  device = null;
                }
                
                final deviceName = device?.deviceName ?? deviceMac.toUpperCase();
                final deviceIp = device?.ipv4 ?? deviceInfo.deviceIp;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.computer, color: Colors.blue),
                    ),
                    title: Text(
                      deviceName.isNotEmpty ? deviceName : deviceMac.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IP: ${deviceIp.isNotEmpty ? deviceIp : deviceInfo.deviceIp}'),
                        Text(
                          'MAC: ${deviceMac.toUpperCase()}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.pop(context, deviceMac),
                  ),
                );
              }).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    );
  }
  
  // Handle camera selection with device choice
  Future<void> _selectCamera(Camera camera, bool select) async {
    if (select) {
      // Check if camera is on multiple devices
      if (camera.currentDevices.length > 1) {
        final selectedDevice = await _showDeviceSelectionDialog(camera);
        if (selectedDevice == null) {
          return; // User cancelled
        }
        _cameraSelectedDevice[camera] = selectedDevice;
      } else if (camera.currentDevices.isNotEmpty) {
        // Single device, auto-select it
        _cameraSelectedDevice[camera] = camera.currentDevices.keys.first;
      }
      
      if (!_selectedCameras.contains(camera)) {
        setState(() {
          _selectedCameras.add(camera);
        });
      }
    } else {
      setState(() {
        _selectedCameras.remove(camera);
        _cameraRecordings.remove(camera);
        _cameraErrors.remove(camera);
        _cameraSelectedDevice.remove(camera);
        _cameraDeviceRecordings.remove(camera);
        _cameraDeviceErrors.remove(camera);
        _cameraDeviceDateFormats.remove(camera);
      });
    }
    _updateRecordingsForSelectedDay();
  }
  
  // Force reload all recordings (used when date changes)
  void _reloadAllRecordings() {
    setState(() {
      _cameraRecordings.clear();
      _cameraErrors.clear();
      _cameraDateFormats.clear();
      _cameraDeviceRecordings.clear();
      _cameraDeviceErrors.clear();
      _cameraDeviceDateFormats.clear();
    });
    _updateRecordingsForSelectedDay();
  }
  
  // Check for new recordings periodically (called every 1 minute by timer)
  Future<void> _checkForNewRecordings() async {
    if (_selectedDay == null || _selectedCameras.isEmpty || !mounted) return;
    
    // Only check for today's recordings
    final today = DateTime.now();
    final selectedDate = _selectedDay!;
    if (selectedDate.year != today.year || 
        selectedDate.month != today.month || 
        selectedDate.day != today.day) {
      print('[MultiRecordings] Skipping refresh - not today');
      return;
    }
    
    print('[MultiRecordings] Checking for new recordings...');
    
    final selectedDayFormatted = DateFormat('yyyy_MM_dd').format(_selectedDay!);
    final selectedDayFormattedAlt = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    for (var camera in _selectedCameras) {
      // Multi-device cameras
      if (camera.currentDevices.length > 1) {
        for (var deviceMac in camera.currentDevices.keys) {
          CameraDevice? device;
          String? recordingsUrl;
          
          try {
            device = cameraDevicesProvider.devices.values.firstWhere(
              (d) => d.macAddress == deviceMac || d.macKey == deviceMac,
            );
            recordingsUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/';
          } catch (e) {
            final deviceInfo = camera.currentDevices[deviceMac];
            if (deviceInfo != null && deviceInfo.deviceIp.isNotEmpty) {
              recordingsUrl = 'http://${deviceInfo.deviceIp}:8080/Rec/${camera.name}/';
            }
          }
          
          if (recordingsUrl != null) {
            await _refreshRecordingsForDevice(camera, deviceMac, recordingsUrl, selectedDayFormatted, selectedDayFormattedAlt);
          }
        }
      } else {
        // Single device camera
        CameraDevice? device;
        final selectedDeviceMac = _cameraSelectedDevice[camera];
        
        if (selectedDeviceMac != null && camera.currentDevices.containsKey(selectedDeviceMac)) {
          try {
            device = cameraDevicesProvider.devices.values.firstWhere(
              (d) => d.macAddress == selectedDeviceMac || d.macKey == selectedDeviceMac,
            );
          } catch (e) {
            device = cameraDevicesProvider.getDeviceForCamera(camera);
          }
        } else {
          device = cameraDevicesProvider.getDeviceForCamera(camera);
        }
        
        if (device != null) {
          final recordingsUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/';
          await _refreshSingleCameraRecordings(camera, recordingsUrl, selectedDayFormatted, selectedDayFormattedAlt);
        }
      }
    }
    
    print('[MultiRecordings] Refresh check completed');
  }
  
  // Refresh recordings for a multi-device camera's specific device
  Future<void> _refreshRecordingsForDevice(Camera camera, String deviceMac, String recordingsUrl, String formattedDate, String formattedDateAlt) async {
    try {
      final response = await http.get(Uri.parse(recordingsUrl));
      if (response.statusCode == 200) {
        final html = response.body;
        final dateRegExp = RegExp(r'<a href="([^"]+)/">');
        final dateMatches = dateRegExp.allMatches(html);
        final dates = dateMatches.map((m) => m.group(1)!).toList();
        
        String? foundDate;
        if (dates.contains(formattedDate)) {
          foundDate = formattedDate;
        } else if (dates.contains(formattedDateAlt)) {
          foundDate = formattedDateAlt;
        }
        
        if (foundDate != null) {
          final dateUrl = '$recordingsUrl$foundDate/';
          final dateResponse = await http.get(Uri.parse(dateUrl));
          
          if (dateResponse.statusCode == 200) {
            final dateHtml = utf8.decode(dateResponse.bodyBytes);
            
            final mkvRegExp = RegExp(r'<a href="([^"]+\.mkv)"');
            final m3u8RegExp = RegExp(r'<a href="([^"]+\.m3u8)"');
            final mp4RegExp = RegExp(r'<a href="([^"]+\.mp4)"');
            
            final mkvRecordings = mkvRegExp.allMatches(dateHtml).map((m) => m.group(1)!).toList();
            final m3u8Recordings = m3u8RegExp.allMatches(dateHtml).map((m) => m.group(1)!).toList();
            final mp4Recordings = mp4RegExp.allMatches(dateHtml).map((m) => m.group(1)!).toList();
            
            final newRecordings = [...mkvRecordings, ...m3u8Recordings, ...mp4Recordings];
            final existingRecordings = _cameraDeviceRecordings[camera]?[deviceMac] ?? [];
            
            if (newRecordings.length > existingRecordings.length) {
              print('[MultiRecordings] New recordings found for ${camera.name}/$deviceMac: ${newRecordings.length - existingRecordings.length} new');
              if (mounted) {
                setState(() {
                  if (_cameraDeviceRecordings[camera] == null) {
                    _cameraDeviceRecordings[camera] = {};
                  }
                  _cameraDeviceRecordings[camera]![deviceMac] = newRecordings;
                });
              }
            }
          }
        }
      }
    } catch (e) {
      print('[MultiRecordings] Error refreshing recordings for ${camera.name}/$deviceMac: $e');
    }
  }
  
  // Refresh recordings for a single-device camera
  Future<void> _refreshSingleCameraRecordings(Camera camera, String recordingsUrl, String formattedDate, String formattedDateAlt) async {
    try {
      final response = await http.get(Uri.parse(recordingsUrl));
      if (response.statusCode == 200) {
        final html = response.body;
        final dateRegExp = RegExp(r'<a href="([^"]+)/">');
        final dateMatches = dateRegExp.allMatches(html);
        final dates = dateMatches.map((m) => m.group(1)!).toList();
        
        String? foundDate;
        if (dates.contains(formattedDate)) {
          foundDate = formattedDate;
        } else if (dates.contains(formattedDateAlt)) {
          foundDate = formattedDateAlt;
        }
        
        if (foundDate != null) {
          final dateUrl = '$recordingsUrl$foundDate/';
          final dateResponse = await http.get(Uri.parse(dateUrl));
          
          if (dateResponse.statusCode == 200) {
            final dateHtml = utf8.decode(dateResponse.bodyBytes);
            
            final mkvRegExp = RegExp(r'<a href="([^"]+\.mkv)"');
            final m3u8RegExp = RegExp(r'<a href="([^"]+\.m3u8)"');
            final mp4RegExp = RegExp(r'<a href="([^"]+\.mp4)"');
            
            final mkvRecordings = mkvRegExp.allMatches(dateHtml).map((m) => m.group(1)!).toList();
            final m3u8Recordings = m3u8RegExp.allMatches(dateHtml).map((m) => m.group(1)!).toList();
            final mp4Recordings = mp4RegExp.allMatches(dateHtml).map((m) => m.group(1)!).toList();
            
            final newRecordings = [...mkvRecordings, ...m3u8Recordings, ...mp4Recordings];
            final existingRecordings = _cameraRecordings[camera] ?? [];
            
            if (newRecordings.length > existingRecordings.length) {
              print('[MultiRecordings] New recordings found for ${camera.name}: ${newRecordings.length - existingRecordings.length} new');
              if (mounted) {
                setState(() {
                  _cameraRecordings[camera] = newRecordings;
                });
              }
            }
          }
        }
      }
    } catch (e) {
      print('[MultiRecordings] Error refreshing recordings for ${camera.name}: $e');
    }
  }
  
  void _updateRecordingsForSelectedDay() {
    if (_selectedDay == null || _selectedCameras.isEmpty) return;
    
    // Don't clear all - only clean up cameras that are no longer selected
    // Remove recordings for cameras that are no longer in selectedCameras
    final camerasToRemove = <Camera>[];
    for (var camera in _cameraRecordings.keys) {
      if (!_selectedCameras.contains(camera)) {
        camerasToRemove.add(camera);
      }
    }
    for (var camera in _cameraDeviceRecordings.keys) {
      if (!_selectedCameras.contains(camera) && !camerasToRemove.contains(camera)) {
        camerasToRemove.add(camera);
      }
    }
    for (var camera in camerasToRemove) {
      _cameraRecordings.remove(camera);
      _cameraErrors.remove(camera);
      _cameraDateFormats.remove(camera);
      _cameraDeviceRecordings.remove(camera);
      _cameraDeviceErrors.remove(camera);
      _cameraDeviceDateFormats.remove(camera);
    }
    
    // Find cameras that need loading (not yet in recordings maps)
    final camerasToLoad = <Camera>[];
    for (var camera in _selectedCameras) {
      final hasRegularRecordings = _cameraRecordings.containsKey(camera);
      final hasDeviceRecordings = _cameraDeviceRecordings.containsKey(camera);
      if (!hasRegularRecordings && !hasDeviceRecordings) {
        camerasToLoad.add(camera);
      }
    }
    
    // If no cameras need loading, just return
    if (camerasToLoad.isEmpty) {
      print('[MultiRecordings] All cameras already have recordings loaded');
      return;
    }
    
    setState(() {
      _isLoadingRecordings = true;
      _loadingError = '';
    });
    
    print('[MultiRecordings] Loading recordings for ${camerasToLoad.length} cameras (${_selectedCameras.length} total selected)');
    
    final selectedDayFormatted = DateFormat('yyyy_MM_dd').format(_selectedDay!);
    final selectedDayFormattedAlt = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final futures = <Future>[];
    
    for (var camera in camerasToLoad) {
      final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
      
      print('[MultiRecordings] Camera: ${camera.name} (MAC: ${camera.mac})');
      print('[MultiRecordings] Camera currentDevices: ${camera.currentDevices.keys.join(", ")}');
      
      // If camera is on multiple devices, load recordings from ALL devices
      if (camera.currentDevices.length > 1) {
        print('[MultiRecordings] Camera ${camera.name} is on ${camera.currentDevices.length} devices, loading from all');
        
        // Initialize multi-device maps for this camera
        _cameraDeviceRecordings[camera] = {};
        _cameraDeviceErrors[camera] = {};
        _cameraDeviceDateFormats[camera] = {};
        
        for (var deviceMac in camera.currentDevices.keys) {
          CameraDevice? device;
          try {
            device = cameraDevicesProvider.devices.values.firstWhere(
              (d) => d.macAddress == deviceMac || d.macKey == deviceMac,
            );
            // Device found - load recordings
            final recordingsUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/';
            print('[MultiRecordings] Loading from device ${device.deviceName ?? deviceMac} (IP: ${device.ipv4})');
            final future = _loadRecordingsForCameraDevice(camera, deviceMac, recordingsUrl, selectedDayFormatted, selectedDayFormattedAlt);
            futures.add(future);
          } catch (e) {
            // Try to get device info from currentDevices
            final deviceInfo = camera.currentDevices[deviceMac];
            if (deviceInfo != null && deviceInfo.deviceIp.isNotEmpty) {
              // Create a temporary recording URL using the IP from currentDevices
              final recordingsUrl = 'http://${deviceInfo.deviceIp}:8080/Rec/${camera.name}/';
              print('[MultiRecordings] Loading from device $deviceMac (IP: ${deviceInfo.deviceIp})');
              final future = _loadRecordingsForCameraDevice(camera, deviceMac, recordingsUrl, selectedDayFormatted, selectedDayFormattedAlt);
              futures.add(future);
            }
          }
        }
      } else {
        // Single device - use existing logic
        CameraDevice? device;
        final selectedDeviceMac = _cameraSelectedDevice[camera];
        
        if (selectedDeviceMac != null && camera.currentDevices.containsKey(selectedDeviceMac)) {
          try {
            device = cameraDevicesProvider.devices.values.firstWhere(
              (d) => d.macAddress == selectedDeviceMac || d.macKey == selectedDeviceMac,
            );
          } catch (e) {
            device = cameraDevicesProvider.getDeviceForCamera(camera);
          }
        } else {
          device = cameraDevicesProvider.getDeviceForCamera(camera);
        }
        
        if (device != null) {
          final recordingsUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/';
          print('[MultiRecordings] Single device - Loading from ${device.ipv4}');
          final future = _loadRecordingsForCamera(camera, recordingsUrl, selectedDayFormatted, selectedDayFormattedAlt);
          futures.add(future);
        } else {
          print('[MultiRecordings] ERROR: No device found for camera ${camera.name}');
        }
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
  
  // Load recordings for a specific camera+device combination (for multi-device cameras)
  Future<void> _loadRecordingsForCameraDevice(Camera camera, String deviceMac, String recordingsUrl, String formattedDate, String formattedDateAlt) async {
    try {
      print('[MultiRecordings] Loading recordings for camera: ${camera.name} from device: $deviceMac');
      print('[MultiRecordings] Recordings URL: $recordingsUrl');
      
      final response = await http.get(Uri.parse(recordingsUrl));
      print('[MultiRecordings] Response status for $deviceMac: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final html = response.body;
        
        final dateRegExp = RegExp(r'<a href="([^"]+)/">');
        final dateMatches = dateRegExp.allMatches(html);
        final dates = dateMatches.map((m) => m.group(1)!).toList();
        
        String? foundDate;
        if (dates.contains(formattedDate)) {
          foundDate = formattedDate;
          _cameraDeviceDateFormats[camera] ??= {};
          _cameraDeviceDateFormats[camera]![deviceMac] = formattedDate;
        } else if (dates.contains(formattedDateAlt)) {
          foundDate = formattedDateAlt;
          _cameraDeviceDateFormats[camera] ??= {};
          _cameraDeviceDateFormats[camera]![deviceMac] = formattedDateAlt;
        }
        
        if (foundDate != null) {
          final dateUrl = '$recordingsUrl$foundDate/';
          final dateResponse = await http.get(Uri.parse(dateUrl));
          
          if (dateResponse.statusCode == 200) {
            final html = utf8.decode(dateResponse.bodyBytes);
            
            final mkvRegExp = RegExp(r'<a href="([^"]+\.mkv)"');
            final mkvMatches = mkvRegExp.allMatches(html);
            final mkvRecordings = mkvMatches.map((m) => m.group(1)!).toList();
            
            final m3u8RegExp = RegExp(r'<a href="([^"]+\.m3u8)"');
            final m3u8Matches = m3u8RegExp.allMatches(html);
            final m3u8Recordings = m3u8Matches.map((m) => m.group(1)!).toList();
            
            final mp4RegExp = RegExp(r'<a href="([^"]+\.mp4)"');
            final mp4Matches = mp4RegExp.allMatches(html);
            final mp4Recordings = mp4Matches.map((m) => m.group(1)!).toList();
            
            final allRecordings = [...mkvRecordings, ...m3u8Recordings, ...mp4Recordings];
            
            print('[MultiRecordings] Found ${allRecordings.length} recordings for ${camera.name} from device $deviceMac');
            
            if (mounted) {
              setState(() {
                _cameraDeviceRecordings[camera] ??= {};
                _cameraDeviceRecordings[camera]![deviceMac] = allRecordings;
              });
            }
          }
        } else {
          print('[MultiRecordings] No recordings for $formattedDate from device $deviceMac');
          if (mounted) {
            setState(() {
              _cameraDeviceRecordings[camera] ??= {};
              _cameraDeviceRecordings[camera]![deviceMac] = [];
            });
          }
        }
      } else {
        throw Exception('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      print('[MultiRecordings] Error loading from $deviceMac: $e');
      if (mounted) {
        setState(() {
          _cameraDeviceErrors[camera] ??= {};
          _cameraDeviceErrors[camera]![deviceMac] = 'Error: $e';
          _cameraDeviceRecordings[camera] ??= {};
          _cameraDeviceRecordings[camera]![deviceMac] = [];
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
    print('[Select] Recording selected: ${camera.name} - $recording');
    print('[Select] Multi-selection mode: $_isMultiSelectionMode');
    
    setState(() {
      if (_isMultiSelectionMode) {
        print('[Select] In multi-selection mode');
        // Çoklu seçim modunda
        final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
        final device = cameraDevicesProvider.getDeviceForCamera(camera);
        
        if (device != null) {
          // Include date folder in the download URL
          final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay ?? DateTime.now());
          final completeUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/$dateStr/$recording';
          print('[Select] Generated URL: $completeUrl');
          
          if (_selectedForDownload.contains(completeUrl)) {
            print('[Select] Removing from selection');
            _selectedForDownload.remove(completeUrl);
          } else {
            print('[Select] Adding to selection');
            _selectedForDownload.add(completeUrl);
          }
          print('[Select] Total selected: ${_selectedForDownload.length}');
        } else {
          print('[Select] ERROR: No device found for camera ${camera.name}');
        }
      } else {
        print('[Select] In normal mode, opening video player');
        // Normal modda - Popup player aç
        _openVideoPlayerPopup(camera, recording);
      }
    });
  }
  
  void _openVideoPlayerPopup(Camera camera, String recording) {
    print('[MultiRecordings] _openVideoPlayerPopup called with seekTime: $_pendingSeekTime');
    final device = _getDeviceForCamera(camera);
    
    if (device != null && _selectedDay != null) {
      // Kamera için hangi tarih formatının çalıştığını kontrol et - MAC karşılaştırması ile
      String? dateFormat;
      for (var entry in _cameraDateFormats.entries) {
        if (entry.key.mac == camera.mac) {
          dateFormat = entry.value;
          break;
        }
      }
      dateFormat ??= _cameraDateFormats[camera];
      
      final recordingUrl = dateFormat != null 
          ? 'http://${device.ipv4}:8080/Rec/${camera.name}/$dateFormat/$recording'
          : 'http://${device.ipv4}:8080/Rec/${camera.name}/${DateFormat('yyyy-MM-dd').format(_selectedDay!)}/$recording';
      
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
    print('[Toggle] Toggling multi-selection mode. Before: $_isMultiSelectionMode');
    setState(() {
      _isMultiSelectionMode = !_isMultiSelectionMode;
      if (!_isMultiSelectionMode) {
        print('[Toggle] Clearing selected downloads. Count was: ${_selectedForDownload.length}');
        _selectedForDownload.clear();
      }
    });
    print('[Toggle] Multi-selection mode after toggle: $_isMultiSelectionMode');
  }
  
  void _downloadSelectedRecordings() async {
    print('[Download] Starting download process...');
    print('[Download] Selected recordings count: ${_selectedForDownload.length}');
    print('[Download] Selected recordings URLs: $_selectedForDownload');
    
    if (_selectedForDownload.isEmpty) {
      print('[Download] No recordings selected, returning...');
      return;
    }
    
    print('[Download] Checking permissions...');
    // İzinleri kontrol et
    final permissionStatus = await _checkAndRequestPermissions();
    if (!permissionStatus) {
      print('[Download] Permission denied!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission required to download recordings'))
      );
      return;
    }
    print('[Download] Permission granted!');
    
    print('[Download] Getting download directory...');
    // İndirme klasörünü al
    final downloadDir = await _getDownloadDirectory();
    if (downloadDir == null) {
      print('[Download] Failed to get download directory!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get download directory'))
      );
      return;
    }
    print('[Download] Download directory: ${downloadDir.path}');
    
    print('[Download] Starting individual downloads...');
    // İndirme işlemlerini başlat
    for (final recordingUrl in _selectedForDownload) {
      final fileName = recordingUrl.split('/').last;
      final filePath = '${downloadDir.path}/$fileName';
      
      print('[Download] Processing: $recordingUrl');
      print('[Download] File name: $fileName');
      print('[Download] File path: $filePath');
      
      try {
        print('[Download] Making HTTP request to: $recordingUrl');
        // İlerleme göstergesi ile indirme işlemini başlat
        final response = await http.get(Uri.parse(recordingUrl));
        
        print('[Download] HTTP Response status: ${response.statusCode}');
        print('[Download] HTTP Response headers: ${response.headers}');
        print('[Download] HTTP Response body length: ${response.bodyBytes.length}');
        
        if (response.statusCode == 200) {
          print('[Download] Creating file at: $filePath');
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          print('[Download] File written successfully!');
          
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
          print('[Download] HTTP Error: ${response.statusCode}');
          print('[Download] HTTP Error body: ${response.body}');
          throw Exception('Failed to download: ${response.statusCode}');
        }
      } catch (e) {
        print('[Download] Exception occurred: $e');
        print('[Download] Exception type: ${e.runtimeType}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading $fileName: $e'))
        );
      }
    }
    
    print('[Download] All downloads completed!');
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
    print('[GetDir] Starting _getDownloadDirectory...');
    
    try {
      if (Platform.isAndroid) {
        print('[GetDir] Platform is Android');
        return await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        print('[GetDir] Platform is iOS');
        return await getApplicationDocumentsDirectory();
      } else {
        print('[GetDir] Platform is desktop (macOS/Windows/Linux)');
        // macOS, Windows, Linux için - desktop
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
          print('[GetDir] Showing download location dialog...');
          // Desktop için kullanıcıya yer seçtirme seçeneği sun
          final shouldShowPicker = await _showDownloadLocationDialog();
          print('[GetDir] Dialog result: $shouldShowPicker');
          
          if (!shouldShowPicker) {
            print('[GetDir] User chose Downloads folder');
            final dir = await getDownloadsDirectory();
            print('[GetDir] Downloads directory: ${dir?.path}');
            return dir;
          } else {
            print('[GetDir] User chose custom location (not implemented yet)');
            // Şimdilik Downloads klasörünü kullan (file picker sonra eklenecek)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File picker will be implemented soon. Using Downloads folder.'))
            );
            final dir = await getDownloadsDirectory();
            print('[GetDir] Fallback to Downloads directory: ${dir?.path}');
            return dir;
          }
        }
        print('[GetDir] Unknown desktop platform, using Downloads');
        return await getDownloadsDirectory();
      }
    } catch (e) {
      print('[GetDir] Exception occurred: $e');
      print('[GetDir] Exception type: ${e.runtimeType}');
      return null;
    }
  }
  
  Future<bool> _showDownloadLocationDialog() async {
    print('[Dialog] Showing download location dialog...');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        print('[Dialog] Building dialog widget...');
        return AlertDialog(
          title: const Text('Download Location'),
          content: const Text('Choose download location:'),
          actions: [
            TextButton(
              onPressed: () {
                print('[Dialog] Downloads Folder button pressed');
                Navigator.of(context).pop(false);
              },
              child: const Text('Downloads Folder'),
            ),
            TextButton(
              onPressed: () {
                print('[Dialog] Choose Location button pressed');
                Navigator.of(context).pop(true);
              },
              child: const Text('Choose Location'),
            ),
          ],
        );
      },
    );
    
    print('[Dialog] Dialog result: $result');
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
    // Check if we have any recordings at all
    if (_cameraRecordings.isEmpty && _cameraDeviceRecordings.isEmpty) return [];
    
    print('[MultiRecordings] Grouping recordings by time...');
    
    // Tüm kayıtlardan zaman damgalarını çıkar
    final List<RecordingTime> allRecordings = [];
    
    // Add recordings from single-device cameras
    for (final entry in _cameraRecordings.entries) {
      final camera = entry.key;
      final recordings = entry.value;
      
      print('[MultiRecordings] Camera ${camera.name} has ${recordings.length} recordings');
      
      for (final recording in recordings) {
        final recordingName = recording.contains('/') ? recording.split('/').last : recording;
        final timestamp = _parseTimestampFromFilename(recordingName);
        
        if (timestamp != null) {
          allRecordings.add(RecordingTime(camera, recording, timestamp));
        }
      }
    }
    
    // Add recordings from multi-device cameras (all devices)
    for (final entry in _cameraDeviceRecordings.entries) {
      final camera = entry.key;
      final deviceRecordings = entry.value;
      
      for (final deviceEntry in deviceRecordings.entries) {
        final deviceMac = deviceEntry.key;
        final recordings = deviceEntry.value;
        
        print('[MultiRecordings] Camera ${camera.name} from device $deviceMac has ${recordings.length} recordings');
        
        for (final recording in recordings) {
          final recordingName = recording.contains('/') ? recording.split('/').last : recording;
          final timestamp = _parseTimestampFromFilename(recordingName);
          
          if (timestamp != null) {
            // Add with device info for later use
            allRecordings.add(RecordingTime(camera, recording, timestamp, deviceMac: deviceMac));
          }
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
    final Map<Camera, String> cameraDeviceIps = {};
    final Map<Camera, String> dateFormats = {};
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    for (final recording in recordingGroup) {
      cameraRecordings[recording.camera] = recording.recording;
      
      // Get device IP for this camera (especially important for multi-device cameras)
      if (recording.deviceMac != null) {
        // Multi-device camera - find the specific device IP
        try {
          final device = cameraDevicesProvider.devices.values.firstWhere(
            (d) => d.macAddress == recording.deviceMac || d.macKey == recording.deviceMac,
          );
          cameraDeviceIps[recording.camera] = device.ipv4;
        } catch (e) {
          // Try from currentDevices
          final deviceInfo = recording.camera.currentDevices[recording.deviceMac];
          if (deviceInfo != null && deviceInfo.deviceIp.isNotEmpty) {
            cameraDeviceIps[recording.camera] = deviceInfo.deviceIp;
          }
        }
        
        // Get date format for this device
        String? format;
        for (var entry in _cameraDeviceDateFormats.entries) {
          if (entry.key.mac == recording.camera.mac) {
            format = entry.value[recording.deviceMac];
            break;
          }
        }
        if (format != null) {
          dateFormats[recording.camera] = format;
        }
      } else {
        // Single device camera - use regular lookup
        final device = cameraDevicesProvider.getDeviceForCamera(recording.camera);
        if (device != null) {
          cameraDeviceIps[recording.camera] = device.ipv4;
        }
        
        // Get date format
        String? format;
        for (var entry in _cameraDateFormats.entries) {
          if (entry.key.mac == recording.camera.mac) {
            format = entry.value;
            break;
          }
        }
        format ??= _cameraDateFormats[recording.camera];
        if (format != null) {
          dateFormats[recording.camera] = format;
        }
      }
    }
    
    print('[MultiRecordings] Opening MultiWatch with ${cameraRecordings.length} cameras');
    print('[MultiRecordings] Device IPs: ${cameraDeviceIps.entries.map((e) => "${e.key.name}: ${e.value}").join(", ")}');
    print('[MultiRecordings] Date formats: ${dateFormats.entries.map((e) => "${e.key.name}: ${e.value}").join(", ")}');
    
    // Multi Watch sayfasını aç
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiWatchScreen(
          cameraRecordings: cameraRecordings,
          selectedDate: _selectedDay!,
          cameraDateFormats: dateFormats,
          cameraDeviceIps: cameraDeviceIps,
        ),
      ),
    );
  }
  
  void _watchClosestRecordings() {
    if (_selectedCameras.isEmpty || _selectedDay == null) return;
    
    // Find closest recordings from each selected camera
    final Map<Camera, String> closestRecordings = {};
    final Map<Camera, String> cameraDeviceIps = {};
    final Map<Camera, String> dateFormats = {};
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    for (final camera in _selectedCameras) {
      final recordings = _cameraRecordings[camera];
      if (recordings != null && recordings.isNotEmpty) {
        closestRecordings[camera] = recordings.first;
        
        // Get device IP
        final device = cameraDevicesProvider.getDeviceForCamera(camera);
        if (device != null) {
          cameraDeviceIps[camera] = device.ipv4;
        }
        
        // Get date format using MAC comparison
        String? format;
        for (var entry in _cameraDateFormats.entries) {
          if (entry.key.mac == camera.mac) {
            format = entry.value;
            break;
          }
        }
        format ??= _cameraDateFormats[camera];
        if (format != null) {
          dateFormats[camera] = format;
        }
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
            cameraDateFormats: dateFormats,
            cameraDeviceIps: cameraDeviceIps,
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
    _refreshTimer?.cancel();
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
            onPressed: () {
              print('[Button] Multi-select toggle pressed! Current mode: $_isMultiSelectionMode');
              _toggleMultiSelectionMode();
            },
          ),
          
          // İndirme butonu (sadece çoklu seçim modunda)
          if (_isMultiSelectionMode)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download Selected',
              onPressed: _selectedForDownload.isNotEmpty ? () {
                print('[Button] Download button pressed! Selected count: ${_selectedForDownload.length}');
                _downloadSelectedRecordings();
              } : null,
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
    
    // Calculate total tabs: 
    // - 1 for group watch (if groups exist)
    // - 1 tab per camera for single-device cameras
    // - N tabs per camera for multi-device cameras (one per device)
    int totalTabs = groups.isNotEmpty ? 1 : 0;
    
    // Count tabs for each selected camera
    for (var camera in _selectedCameras) {
      // Check if this is a multi-device camera
      if (camera.currentDevices.length > 1) {
        // Multi-device camera: one tab per device (use currentDevices count, not loaded recordings)
        totalTabs += camera.currentDevices.length;
      } else {
        // Single-device camera: one tab
        totalTabs += 1;
      }
    }
    
    print('[MultiRecordings] Total tabs calculated: $totalTabs (groups: ${groups.isNotEmpty ? 1 : 0}, cameras: ${_selectedCameras.length})');
    print('[MultiRecordings] _cameraRecordings keys: ${_cameraRecordings.keys.map((c) => c.name).join(", ")}');
    print('[MultiRecordings] _cameraDeviceRecordings keys: ${_cameraDeviceRecordings.keys.map((c) => "${c.name}(${_cameraDeviceRecordings[c]?.length ?? 0} devices)").join(", ")}');
    
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
              // Tabs for each camera (and each device for multi-device cameras)
              ..._buildCameraTabs(),
            ],
          ),
          
          // Tab içerikleri
          Expanded(
            child: TabBarView(
              children: [
                // Toplu İzle içeriği - EN BAŞTA
                if (groups.isNotEmpty)
                  _buildGroupRecordingsList(groups),
                // Content for each camera/device
                ..._buildCameraTabContents(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build tabs for cameras (with separate tabs for each device on multi-device cameras)
  List<Widget> _buildCameraTabs() {
    final tabs = <Widget>[];
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    for (var camera in _selectedCameras) {
      // Check if camera is on multiple devices
      if (camera.currentDevices.length > 1) {
        // Multi-device camera: create a tab for each device
        final deviceRecordings = _cameraDeviceRecordings[camera] ?? {};
        
        for (var deviceMac in camera.currentDevices.keys) {
          final recordings = deviceRecordings[deviceMac] ?? [];
          
          // Get device name
          CameraDevice? device;
          try {
            device = cameraDevicesProvider.devices.values.firstWhere(
              (d) => d.macAddress == deviceMac || d.macKey == deviceMac,
            );
          } catch (e) {
            device = null;
          }
          final deviceName = device?.deviceName ?? deviceMac.substring(deviceMac.length > 8 ? deviceMac.length - 8 : 0).toUpperCase();
          
          tabs.add(
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.computer, size: 10, color: Colors.orange.shade300),
                          const SizedBox(width: 2),
                          Text(
                            deviceName,
                            style: TextStyle(fontSize: 9, color: Colors.orange.shade300),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
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
            ),
          );
        }
      } else {
        // Single-device camera: use normal recordings
        final recordings = _cameraRecordings[camera] ?? [];
        tabs.add(
          Tab(
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
          ),
        );
      }
    }
    
    return tabs;
  }
  
  // Build tab contents for cameras
  List<Widget> _buildCameraTabContents() {
    final contents = <Widget>[];
    
    for (var camera in _selectedCameras) {
      // Check if camera is on multiple devices
      if (camera.currentDevices.length > 1) {
        // Multi-device camera: create content for each device
        final deviceRecordings = _cameraDeviceRecordings[camera] ?? {};
        
        for (var deviceMac in camera.currentDevices.keys) {
          final recordings = deviceRecordings[deviceMac] ?? [];
          contents.add(_buildCameraDeviceRecordingsList(camera, deviceMac, recordings));
        }
      } else {
        // Single-device camera
        final recordings = _cameraRecordings[camera] ?? [];
        contents.add(_buildCameraRecordingsList(camera, recordings));
      }
    }
    
    return contents;
  }
  
  // Build a single recording tile (reusable for both single and multi-device cameras)
  Widget _buildRecordingTile(Camera camera, String recording, {String? deviceMac, String? deviceIp}) {
    final recordingName = recording.split('/').last;
    final timestamp = _parseTimestampFromFilename(recordingName);
    
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    // Determine which device to use
    String? resolvedDeviceIp = deviceIp;
    if (resolvedDeviceIp == null || resolvedDeviceIp.isEmpty) {
      final device = cameraDevicesProvider.getDeviceForCamera(camera);
      resolvedDeviceIp = device?.ipv4 ?? '';
    }
    
    // Build recording URL
    String recordingUrl = '';
    if (resolvedDeviceIp.isNotEmpty && _selectedDay != null) {
      String? dateFormat;
      if (deviceMac != null) {
        // Try MAC comparison first
        for (var entry in _cameraDeviceDateFormats.entries) {
          if (entry.key.mac == camera.mac) {
            dateFormat = entry.value[deviceMac];
            break;
          }
        }
        dateFormat ??= _cameraDeviceDateFormats[camera]?[deviceMac];
      } else {
        dateFormat = _cameraDateFormats[camera];
      }
      final formattedDate = dateFormat ?? DateFormat('yyyy-MM-dd').format(_selectedDay!);
      recordingUrl = 'http://$resolvedDeviceIp:8080/Rec/${camera.name}/$formattedDate/$recording';
    }
    
    final isSelected = _isMultiSelectionMode 
        ? _selectedForDownload.contains(recordingUrl)
        : _activeCamera == camera && _activeRecording == recording;
    
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
                recordingName.toLowerCase().endsWith('.m3u8') ? 'M3U8' : 
                recordingName.toLowerCase().endsWith('.mp4') ? 'MP4' : 'MKV',
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
              onPressed: _isMultiSelectionMode ? null : () => _selectRecordingWithDevice(camera, recording, deviceMac, resolvedDeviceIp!),
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _downloadSingleRecording(camera, recording, recordingUrl),
            ),
          ],
        ),
        onTap: () => _selectRecordingWithDevice(camera, recording, deviceMac, resolvedDeviceIp!),
      ),
    );
  }
  
  // Select recording from a specific device
  void _selectRecordingWithDevice(Camera camera, String recording, String? deviceMac, String deviceIp) {
    if (_isMultiSelectionMode) {
      // Multi-selection mode - handle checkbox
      String recordingUrl = '';
      if (deviceIp.isNotEmpty && _selectedDay != null) {
        String? dateFormat;
        if (deviceMac != null) {
          // Try MAC comparison first
          for (var entry in _cameraDeviceDateFormats.entries) {
            if (entry.key.mac == camera.mac) {
              dateFormat = entry.value[deviceMac];
              break;
            }
          }
          dateFormat ??= _cameraDeviceDateFormats[camera]?[deviceMac];
        } else {
          dateFormat = _cameraDateFormats[camera];
        }
        final formattedDate = dateFormat ?? DateFormat('yyyy-MM-dd').format(_selectedDay!);
        recordingUrl = 'http://$deviceIp:8080/Rec/${camera.name}/$formattedDate/$recording';
      }
      
      setState(() {
        if (_selectedForDownload.contains(recordingUrl)) {
          _selectedForDownload.remove(recordingUrl);
        } else {
          _selectedForDownload.add(recordingUrl);
        }
      });
    } else {
      // Normal mode - open video player
      _openVideoPlayerPopupWithDevice(camera, recording, deviceMac, deviceIp);
    }
  }
  
  // Open video player for a specific device
  void _openVideoPlayerPopupWithDevice(Camera camera, String recording, String? deviceMac, String deviceIp) {
    print('[MultiRecordings] Opening video player for ${camera.name} from device $deviceMac ($deviceIp)');
    print('[MultiRecordings] _cameraDeviceDateFormats keys: ${_cameraDeviceDateFormats.keys.map((c) => c.mac).toList()}');
    print('[MultiRecordings] Looking for camera mac: ${camera.mac}');
    
    setState(() {
      _activeCamera = camera;
      _activeRecording = recording;
      _activeDeviceMac = deviceMac;
    });
    
    String recordingUrl = '';
    if (deviceIp.isNotEmpty && _selectedDay != null) {
      String? dateFormat;
      if (deviceMac != null) {
        // Try to find the date format from the map using MAC comparison
        for (var entry in _cameraDeviceDateFormats.entries) {
          if (entry.key.mac == camera.mac) {
            dateFormat = entry.value[deviceMac];
            print('[MultiRecordings] Found date format via MAC comparison: $dateFormat');
            break;
          }
        }
        if (dateFormat == null) {
          dateFormat = _cameraDeviceDateFormats[camera]?[deviceMac];
          print('[MultiRecordings] Direct lookup dateFormat: $dateFormat');
        }
      } else {
        dateFormat = _cameraDateFormats[camera];
      }
      // Default to yyyy-MM-dd (with dashes) as that's more common in this system
      final formattedDate = dateFormat ?? DateFormat('yyyy-MM-dd').format(_selectedDay!);
      recordingUrl = 'http://$deviceIp:8080/Rec/${camera.name}/$formattedDate/$recording';
      print('[MultiRecordings] Final dateFormat used: $formattedDate');
    }
    
    print('[MultiRecordings] Recording URL: $recordingUrl');
    
    if (recordingUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not determine device IP'), backgroundColor: Colors.red),
      );
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.videocam, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${camera.name} - $recording',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (deviceMac != null)
                                Text(
                                  'Device: $deviceIp',
                                  style: TextStyle(color: Colors.orange.shade300, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
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
                      seekTime: _pendingSeekTime,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      // Clear pending seek time after dialog closes
      _pendingSeekTime = null;
    });
  }
  
  // Build recordings list for a specific camera+device combination
  Widget _buildCameraDeviceRecordingsList(Camera camera, String deviceMac, List<String> recordings) {
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    final deviceErrors = _cameraDeviceErrors[camera];
    final deviceError = deviceErrors?[deviceMac];
    
    // Get device info
    CameraDevice? device;
    try {
      device = cameraDevicesProvider.devices.values.firstWhere(
        (d) => d.macAddress == deviceMac || d.macKey == deviceMac,
      );
    } catch (e) {
      device = null;
    }
    final deviceName = device?.deviceName ?? deviceMac.toUpperCase();
    final deviceIp = device?.ipv4 ?? camera.currentDevices[deviceMac]?.deviceIp ?? '';
    
    if (deviceError != null && deviceError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.withOpacity(0.7)),
            const SizedBox(height: 16),
            Text('Error loading from $deviceName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(deviceError, style: TextStyle(color: Colors.red.shade300), textAlign: TextAlign.center),
            ),
          ],
        ),
      );
    }
    
    if (recordings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No recordings on $deviceName', style: const TextStyle(fontSize: 16)),
            Text('IP: $deviceIp', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }
    
    // Device info header
    return Column(
      children: [
        // Device info banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.orange.withOpacity(0.1),
          child: Row(
            children: [
              Icon(Icons.computer, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Device: $deviceName',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const Spacer(),
              Text(
                'IP: $deviceIp',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        // Recordings list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: recordings.length,
            itemBuilder: (context, index) {
              final recording = recordings[index];
              return _buildRecordingTile(camera, recording, deviceMac: deviceMac, deviceIp: deviceIp);
            },
          ),
        ),
      ],
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
        
        // Use the same URL format as video player (with date format)
        String recordingUrl = '';
        if (device != null && _selectedDay != null) {
          // MAC karşılaştırması ile date format bul
          String? dateFormat;
          for (var entry in _cameraDateFormats.entries) {
            if (entry.key.mac == camera.mac) {
              dateFormat = entry.value;
              break;
            }
          }
          dateFormat ??= _cameraDateFormats[camera];
          
          recordingUrl = dateFormat != null 
              ? 'http://${device.ipv4}:8080/Rec/${camera.name}/$dateFormat/$recording'
              : 'http://${device.ipv4}:8080/Rec/${camera.name}/${DateFormat('yyyy-MM-dd').format(_selectedDay!)}/$recording';
        }
        
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
    print('[SingleDownload] Starting single download for: ${camera.name} - $recording');
    print('[SingleDownload] URL: $recordingUrl');
    print('[SingleDownload] Multi-selection mode: $_isMultiSelectionMode');
    
    if (_isMultiSelectionMode) {
      print('[SingleDownload] In multi-selection mode, calling _selectRecording');
      _selectRecording(camera, recording);
      return;
    }
    
    print('[SingleDownload] Checking permissions...');
    // Tekli indirme işlemi
    final permissionStatus = await _checkAndRequestPermissions();
    if (!permissionStatus) {
      print('[SingleDownload] Permission denied!');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission required to download recordings'))
      );
      return;
    }
    print('[SingleDownload] Permission granted!');
    
    print('[SingleDownload] Getting download directory...');
    final downloadDir = await _getDownloadDirectory();
    if (downloadDir == null) {
      print('[SingleDownload] Failed to get download directory!');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get download directory'))
      );
      return;
    }
    print('[SingleDownload] Download directory: ${downloadDir.path}');
    
    final fileName = recording.split('/').last;
    final filePath = '${downloadDir.path}/$fileName';
    print('[SingleDownload] File name: $fileName');
    print('[SingleDownload] File path: $filePath');
    
    try {
      print('[SingleDownload] Making HTTP request...');
      final response = await http.get(Uri.parse(recordingUrl));
      print('[SingleDownload] HTTP Response status: ${response.statusCode}');
      print('[SingleDownload] HTTP Response body length: ${response.bodyBytes.length}');
      
      if (response.statusCode == 200) {
        print('[SingleDownload] Creating file...');
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        print('[SingleDownload] File written successfully!');
        
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
        print('[SingleDownload] HTTP Error: ${response.statusCode}');
        print('[SingleDownload] HTTP Error body: ${response.body}');
        throw Exception('Failed to download: ${response.statusCode}');
      }
    } catch (e) {
      print('[SingleDownload] Exception occurred: $e');
      print('[SingleDownload] Exception type: ${e.runtimeType}');
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
                        _reloadAllRecordings(); // Date changed - reload all
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
                        final hasMultipleDevices = camera.currentDevices.length > 1;
                        final selectedDeviceMac = _cameraSelectedDevice[camera];
                        
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 50, right: 16),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  camera.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              if (hasMultipleDevices)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.devices, size: 12, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${camera.currentDevices.length}',
                                        style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'IP: ${camera.ip}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (isSelected && selectedDeviceMac != null)
                                Text(
                                  'Cihaz: ${selectedDeviceMac.toUpperCase().substring(selectedDeviceMac.length > 8 ? selectedDeviceMac.length - 8 : 0)}',
                                  style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                                ),
                            ],
                          ),
                          value: isSelected,
                          onChanged: (bool? value) {
                            _selectCamera(camera, value ?? false);
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
                        final hasMultipleDevices = camera.currentDevices.length > 1;
                        final selectedDeviceMac = _cameraSelectedDevice[camera];
                        
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 50, right: 16),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  camera.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              if (hasMultipleDevices)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.devices, size: 12, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${camera.currentDevices.length}',
                                        style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'IP: ${camera.ip}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (isSelected && selectedDeviceMac != null)
                                Text(
                                  'Cihaz: ${selectedDeviceMac.toUpperCase().substring(selectedDeviceMac.length > 8 ? selectedDeviceMac.length - 8 : 0)}',
                                  style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                                ),
                            ],
                          ),
                          value: isSelected,
                          onChanged: (bool? value) {
                            _selectCamera(camera, value ?? false);
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
    print('[VideoPlayerPopup] Loading video URL: ${widget.recordingUrl}');
    try {
      _popupPlayer.open(Media(widget.recordingUrl), play: true);
      
      // Listen for player state changes
      _popupPlayer.stream.playing.listen((playing) {
        print('[VideoPlayerPopup] Playing state changed: $playing');
      });
      
      // Listen for log messages
      _popupPlayer.stream.log.listen((log) {
        print('[VideoPlayerPopup] Player log: $log');
      });
      
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
      print('[VideoPlayerPopup] Error in _loadVideo: $e');
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