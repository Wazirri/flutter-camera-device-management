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
      print('[MultiRecordings] PostFrameCallback - Loading cameras');
      _loadAvailableCameras();
    });
    
    // Bugünü seç
    _selectedDay = DateTime.now();
    print('[MultiRecordings] Selected day initialized: $_selectedDay');
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
      
      // Eğer hiç kamera seçilmemişse, ilk kamerayı seç
      if (_selectedCameras.isEmpty && _availableCameras.isNotEmpty) {
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
    });
    
    print('[MultiRecordings] Loading recordings for ${_selectedCameras.length} selected cameras');
    
    // Seçili gün için seçili kameraların kayıtlarını yükle
    final selectedDayFormatted = DateFormat('yyyy_MM_dd').format(_selectedDay!);
    final futures = <Future>[];
    
    for (var camera in _selectedCameras) {
      // Kamera device'ını bul
      final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
      final device = cameraDevicesProvider.getDeviceForCamera(camera);
      
      if (device != null) {
        // Kayıt URL'i oluştur
        final recordingsUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/';
        
        // Kamera için kayıtları yükle
        final future = _loadRecordingsForCamera(camera, recordingsUrl, selectedDayFormatted);
        futures.add(future);
      }
    }
    
    // Tüm kameralar için kayıtlar yüklendiğinde
    Future.wait(futures).then((_) {
      setState(() {
        _isLoadingRecordings = false;
      });
    }).catchError((error) {
      setState(() {
        _isLoadingRecordings = false;
        // Genel hata sadece beklenmedik durumlar için
        print('[MultiRecordings] Unexpected error: $error');
      });
    });
  }
  
  Future<void> _loadRecordingsForCamera(Camera camera, String recordingsUrl, String formattedDate) async {
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
        print('[MultiRecordings] Looking for date: $formattedDate');
        
        if (dates.contains(formattedDate)) {
          // Seçili tarih klasörünün içeriğini al
          final dateUrl = '$recordingsUrl$formattedDate/';
          print('[MultiRecordings] Loading date folder: $dateUrl');
          final dateResponse = await http.get(Uri.parse(dateUrl));
          
          if (dateResponse.statusCode == 200) {
            // MKV dosyalarını bul (single recordings screen ile aynı format)
            final html = utf8.decode(dateResponse.bodyBytes);
            final fileRegExp = RegExp(r'<a href="([^"]+\.mkv)"');
            final fileMatches = fileRegExp.allMatches(html);
            final recordings = fileMatches.map((m) => m.group(1)!).toList();
            
            print('[MultiRecordings] Found ${recordings.length} recordings for ${camera.name}: $recordings');
            
            if (mounted) {
              setState(() {
                _cameraRecordings[camera] = recordings;
              });
            }
          } else {
            print('[MultiRecordings] Failed to load date folder: ${dateResponse.statusCode}');
          }
        } else {
          // Bu tarih için kayıt yok
          print('[MultiRecordings] No recordings found for date $formattedDate for camera ${camera.name}');
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
  
  void _selectRecording(Camera camera, String recording) {
    setState(() {
      if (_isMultiSelectionMode) {
        // Çoklu seçim modunda
        final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
        final device = cameraDevicesProvider.getDeviceForCamera(camera);
        
        if (device != null) {
          final completeUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/$recording';
          
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
    final device = _getDeviceForCamera(camera);
    
    if (device != null && _selectedDay != null) {
      final selectedDayFormatted = DateFormat('yyyy_MM_dd').format(_selectedDay!);
      final recordingUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/$selectedDayFormatted/$recording';
      
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
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
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
        // macOS, Windows, Linux için
        return await getDownloadsDirectory();
      }
    } catch (e) {
      print('Error getting download directory: $e');
      return null;
    }
  }
  
  void _openDownloadedFile(String filePath) {
    // Platform-specific file açma işlemleri burada yapılabilir
    // Şu an için sadece bilgi veriyoruz
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('File saved at: $filePath'))
    );
  }
  
  // Kayıtları ±5dk toleransla grupla
  List<List<RecordingTime>> _groupRecordingsByTime() {
    if (_cameraRecordings.isEmpty) return [];
    
    // Tüm kayıtlardan zaman damgalarını çıkar
    final List<RecordingTime> allRecordings = [];
    
    for (final entry in _cameraRecordings.entries) {
      final camera = entry.key;
      final recordings = entry.value;
      
      for (final recording in recordings) {
        final recordingName = recording.contains('/') ? recording.split('/').last : recording;
        // 2025-06-04_07-06-24.mkv formatından tarih çıkar
        final parts = recordingName.split('_');
        if (parts.length >= 2) {
          final datePart = parts[0]; // 2025-06-04
          final timePart = parts[1].split('.')[0]; // 07-06-24
          
          try {
            final dateComponents = datePart.split('-');
            final timeComponents = timePart.split('-');
            
            if (dateComponents.length == 3 && timeComponents.length == 3) {
              final year = int.parse(dateComponents[0]);
              final month = int.parse(dateComponents[1]);
              final day = int.parse(dateComponents[2]);
              final hour = int.parse(timeComponents[0]);
              final minute = int.parse(timeComponents[1]);
              final second = int.parse(timeComponents[2]);
              
              final timestamp = DateTime(year, month, day, hour, minute, second);
              allRecordings.add(RecordingTime(camera, recording, timestamp));
            }
          } catch (e) {
            print('Error parsing timestamp from $recordingName: $e');
          }
        }
      }
    }
    
    if (allRecordings.isEmpty) return [];
    
    // Zaman damgalarına göre sırala
    allRecordings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // ±5dk toleransla grupla
    final List<List<RecordingTime>> groups = [];
    const Duration tolerance = Duration(minutes: 5);
    
    for (final recording in allRecordings) {
      bool addedToGroup = false;
      
      // Mevcut gruplardan birine eklenebilir mi kontrol et
      for (final group in groups) {
        if (group.isNotEmpty) {
          final groupTime = group.first.timestamp;
          final timeDiff = recording.timestamp.difference(groupTime).abs();
          
          if (timeDiff <= tolerance) {
            // Bu gruba ekle, ama aynı kameradan kayıt yoksa
            final hasThisCamera = group.any((r) => r.camera == recording.camera);
            if (!hasThisCamera) {
              group.add(recording);
              addedToGroup = true;
              break;
            }
          }
        }
      }
      
      // Hiçbir gruba eklenemedi, yeni grup oluştur
      if (!addedToGroup) {
        groups.add([recording]);
      }
    }
    
    // Sadece birden fazla kamerası olan grupları döndür
    return groups.where((group) => group.length > 1).toList();
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
    
    // Tüm kameraları ve kayıtlarını sekmeli bir şekilde göster
    return DefaultTabController(
      length: _cameraRecordings.length,
      child: Column(
        children: [
          // Kamera sekmeleri
          TabBar(
            isScrollable: true,
            tabs: _cameraRecordings.keys.map((camera) {
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
            }).toList(),
          ),
          
          // Toplu İzle sekmesi ve kayıt grupları - Yarı yükseklik
          if (_cameraRecordings.isNotEmpty && 
              _cameraRecordings.values.any((recordings) => recordings.isNotEmpty))
            Expanded(
              flex: 1, // Yarı yükseklik
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Toplu İzle Grupları (±5dk tolerans)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final groups = _groupRecordingsByTime();
                          
                          if (groups.isEmpty) {
                            return const Center(
                              child: Text(
                                'Aynı zaman diliminde birden fazla kameradan kayıt bulunamadı',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          
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
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Kayıt listeleri - Yarı yükseklik
          Expanded(
            flex: 1, // Yarı yükseklik
            child: TabBarView(
              children: _cameraRecordings.entries.map((entry) {
                final camera = entry.key;
                final recordings = entry.value;
                final cameraError = _cameraErrors[camera];
                
                // Eğer bu kamera için hata varsa, hata mesajını göster
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
                    final timestampStr = recordingName.split('_').first;
                    
                    // Zaman damgası formatını ayıkla
                    DateTime? timestamp;
                    try {
                      if (timestampStr.length >= 14) {
                        final year = int.parse(timestampStr.substring(0, 4));
                        final month = int.parse(timestampStr.substring(4, 6));
                        final day = int.parse(timestampStr.substring(6, 8));
                        final hour = int.parse(timestampStr.substring(8, 10));
                        final minute = int.parse(timestampStr.substring(10, 12));
                        final second = int.parse(timestampStr.substring(12, 14));
                        
                        timestamp = DateTime(year, month, day, hour, minute, second);
                      }
                    } catch (e) {
                      print('Error parsing timestamp: $e');
                    }
                    
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
                          isSelected && _isMultiSelectionMode ? Icons.check_circle : Icons.videocam,
                          color: isSelected ? AppTheme.primaryBlue : null,
                        ),
                        title: Text(recordingName),
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
                              onPressed: () async {
                                if (_isMultiSelectionMode) {
                                  _selectRecording(camera, recording);
                                } else {
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
                              },
                            ),
                          ],
                        ),
                        onTap: () => _selectRecording(camera, recording),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
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

  const _VideoPlayerPopup({
    required this.recordingUrl,
    required this.camera,
    required this.recording,
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
        // Video widget
        Video(
          controller: _popupController,
          fit: BoxFit.contain,
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