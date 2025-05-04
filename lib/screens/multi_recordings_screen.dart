import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';
import '../utils/responsive_helper.dart';

class MultiRecordingsScreen extends StatefulWidget {
  const MultiRecordingsScreen({Key? key}) : super(key: key);

  @override
  State<MultiRecordingsScreen> createState() => _MultiRecordingsScreenState();
}

class _MultiRecordingsScreenState extends State<MultiRecordingsScreen> with SingleTickerProviderStateMixin {
  // Seçilen kamera ve kayıtlar
  List<Camera> _availableCameras = [];
  final Map<Camera, List<String>> _cameraRecordings = {};
  
  // Aktif oynatılan kayıt bilgileri
  Camera? _activeCamera;
  String? _activeRecording;
  
  // Media player
  late final Player _player;
  late final VideoController _controller;
  bool _isBuffering = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isFullScreen = false;
  
  // Takvim değişkenleri
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final kFirstDay = DateTime(DateTime.now().year - 1, 1, 1);
  final kLastDay = DateTime(DateTime.now().year + 1, 12, 31);
  
  // Animasyon controller ve animasyonlar
  late AnimationController _animationController;
  late Animation<Offset> _calendarSlideAnimation;
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
    
    // Player'ı başlat
    _player = Player();
    _controller = VideoController(_player);
    
    // Animasyon controller'ı başlat
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
    
    // Animasyonu başlat
    _animationController.forward();
    
    // Player hata dinleyicisi
    _player.stream.error.listen((error) {
      setState(() {
        _hasError = true;
        _errorMessage = "Error playing video: ${error.toString()}";
      });
    });
    
    // Player buffer dinleyicisi
    _player.stream.buffering.listen((buffering) {
      setState(() {
        _isBuffering = buffering;
      });
    });
    
    // Player durum dinleyicisi
    _player.stream.playing.listen((playing) {
      setState(() {
        // Play/pause durumunu güncelle
      });
    });
    
    // Kameraları yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableCameras();
    });
    
    // Bugünü seç
    _selectedDay = DateTime.now();
  }
  
  void _loadAvailableCameras() {
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    final cameras = cameraDevicesProvider.cameras;
    
    setState(() {
      _availableCameras = cameras.where((camera) => 
        camera.ip.isNotEmpty && 
        camera.recordUri.isNotEmpty
      ).toList();
      
      if (_availableCameras.isNotEmpty) {
        _activeCamera = _availableCameras.first;
      }
    });
    
    // Kayıtları yükle
    _updateRecordingsForSelectedDay();
  }
  
  void _updateRecordingsForSelectedDay() {
    if (_selectedDay == null || _availableCameras.isEmpty) return;
    
    setState(() {
      _isLoadingRecordings = true;
      _loadingError = '';
      _cameraRecordings.clear();
    });
    
    // Seçili gün için tüm kameraların kayıtlarını yükle
    final selectedDayFormatted = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final futures = <Future>[];
    
    for (var camera in _availableCameras) {
      // Kamera device'ını bul
      final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
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
        _loadingError = 'Error loading recordings: ${error.toString()}';
      });
    });
  }
  
  Future<void> _loadRecordingsForCamera(Camera camera, String recordingsUrl, String formattedDate) async {
    try {
      final response = await http.get(Uri.parse(recordingsUrl));
      
      if (response.statusCode == 200) {
        // HTML yanıtı ayrıştır
        final html = response.body;
        
        // Klasör bağlantılarını bul (genellikle tarih klasörleri)
        final dateRegExp = RegExp(r'<a href="([^"]+)/">');
        final dateMatches = dateRegExp.allMatches(html);
        final dates = dateMatches.map((m) => m.group(1)!).toList();
        
        if (dates.contains(formattedDate)) {
          // Seçili tarih klasörünün içeriğini al
          final dateResponse = await http.get(Uri.parse('$recordingsUrl$formattedDate/'));
          
          if (dateResponse.statusCode == 200) {
            // MP4 dosyalarını bul
            final fileRegExp = RegExp(r'<a href="([^"]+\.mp4)"');
            final fileMatches = fileRegExp.allMatches(dateResponse.body);
            final recordings = fileMatches.map((m) => m.group(1)!).toList();
            
            if (mounted) {
              setState(() {
                _cameraRecordings[camera] = recordings;
              });
            }
          }
        } else {
          // Bu tarih için kayıt yok
          if (mounted) {
            setState(() {
              _cameraRecordings[camera] = [];
            });
          }
        }
      } else {
        throw Exception('Failed to load recordings: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingError = 'Error loading recordings: $e';
          _cameraRecordings[camera] = [];
        });
      }
    }
  }
  
  void _selectRecording(Camera camera, String recording) {
    setState(() {
      if (_isMultiSelectionMode) {
        // Çoklu seçim modunda
        final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
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
        // Normal modda
        _activeCamera = camera;
        _activeRecording = recording;
        
        // Kayıt başlat
        _loadRecording(camera, recording);
      }
    });
  }
  
  CameraDevice? _getDeviceForCamera(Camera camera) {
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    return cameraDevicesProvider.getDeviceForCamera(camera);
  }
  
  void _loadRecording(Camera camera, String recording) {
    final device = _getDeviceForCamera(camera);
    
    if (device != null) {
      final recordingUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/$recording';
      
      setState(() {
        _hasError = false;
        _errorMessage = '';
      });
      
      // Player'ı durdur ve yeni kaydı yükle
      _player.stop();
      
      try {
        _player.open(Media(recordingUrl), play: true);
      } catch (e) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error playing recording: $e';
        });
      }
    }
  }
  
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
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
  
  @override
  void dispose() {
    _player.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return Scaffold(
        body: _buildVideoPlayer(),
        floatingActionButton: FloatingActionButton(
          mini: true,
          onPressed: _toggleFullScreen,
          child: const Icon(Icons.fullscreen_exit),
        ),
      );
    }
    
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
      body: Column(
        children: [
          // Takvim bölümü
          SlideTransition(
            position: _calendarSlideAnimation,
            child: FadeTransition(
              opacity: _fadeInAnimation,
              child: Card(
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
                        _focusedDay = focusedDay;
                      });
                      _updateRecordingsForSelectedDay();
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    calendarStyle: CalendarStyle(
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
                  ),
                ),
              ),
            ),
          ),
          
          // Video oynatıcı
          if (_activeCamera != null && _activeRecording != null)
            Expanded(
              flex: 3,
              child: SlideTransition(
                position: _playerSlideAnimation,
                child: FadeTransition(
                  opacity: _fadeInAnimation,
                  child: _buildVideoPlayer(),
                ),
              ),
            ),
          
          // Kayıt listesi
          Expanded(
            flex: 2,
            child: SlideTransition(
              position: _playerSlideAnimation,
              child: FadeTransition(
                opacity: _fadeInAnimation,
                child: _buildRecordingsList(),
              ),
            ),
          ),
        ],
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
                ],
              ),
            ),
          ),
          
        // Video Controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: VideoControls(
            player: _player,
            showFullScreenButton: true,
            onFullScreenToggle: _toggleFullScreen,
          ),
        ),
      ],
    );
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
                ? 'No recordings available for ${DateFormat('yyyy-MM-dd').format(_selectedDay!)}'
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
          
          // Kayıt listeleri
          Expanded(
            child: TabBarView(
              children: _cameraRecordings.entries.map((entry) {
                final camera = entry.key;
                final recordings = entry.value;
                
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
                    
                    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
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
}