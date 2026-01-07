import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:intl/intl.dart';
import '../providers/camera_devices_provider_optimized.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';

class MultiWatchScreen extends StatefulWidget {
  final Map<Camera, String> cameraRecordings;
  final DateTime selectedDate;
  final Map<Camera, String>? cameraDateFormats; // Date format per camera

  const MultiWatchScreen({
    Key? key,
    required this.cameraRecordings,
    required this.selectedDate,
    this.cameraDateFormats,
  }) : super(key: key);

  @override
  State<MultiWatchScreen> createState() => _MultiWatchScreenState();
}

class _MultiWatchScreenState extends State<MultiWatchScreen> {
  final Map<Camera, Player> _players = {};
  final Map<Camera, VideoController> _controllers = {};
  final Map<Camera, bool> _isBuffering = {};
  final Map<Camera, bool> _hasError = {};
  final Map<Camera, String> _errorMessages = {};
  final Map<Camera, bool> _isPlaying = {};
  
  // Synchronized playback control
  bool _isSyncPlaying = false;
  Duration _syncPosition = Duration.zero;
  Duration _syncDuration = Duration.zero;
  Player? _masterPlayer; // Reference player for sync
  bool _isSeeking = false;
  
  @override
  void initState() {
    super.initState();
    _initializePlayers();
  }
  
  void _initializePlayers() {
    bool isFirst = true;
    
    for (final entry in widget.cameraRecordings.entries) {
      final camera = entry.key;
      final recording = entry.value;
      
      // Player ve controller oluştur
      final player = Player();
      final controller = VideoController(player);
      
      _players[camera] = player;
      _controllers[camera] = controller;
      _isBuffering[camera] = false;
      _hasError[camera] = false;
      _errorMessages[camera] = '';
      _isPlaying[camera] = false;
      
      // Set first player as master for sync
      if (isFirst) {
        _masterPlayer = player;
        isFirst = false;
        
        // Listen to master player for sync position/duration
        player.stream.position.listen((position) {
          if (mounted && !_isSeeking) {
            setState(() {
              _syncPosition = position;
            });
          }
        });
        
        player.stream.duration.listen((duration) {
          if (mounted && duration != Duration.zero) {
            setState(() {
              _syncDuration = duration;
            });
          }
        });
        
        player.stream.playing.listen((playing) {
          if (mounted) {
            setState(() {
              _isSyncPlaying = playing;
            });
          }
        });
      }
      
      // Player event listeners
      player.stream.error.listen((error) {
        if (mounted) {
          setState(() {
            _hasError[camera] = true;
            _errorMessages[camera] = "Error playing video: ${error.toString()}";
          });
        }
      });
      
      player.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() {
            _isBuffering[camera] = buffering;
          });
        }
      });
      
      player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _isPlaying[camera] = playing;
          });
        }
      });
      
      // Kayıt URL'ini oluştur ve yükle
      _loadRecording(camera, recording);
    }
  }
  
  void _loadRecording(Camera camera, String recording) {
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    final device = cameraDevicesProvider.getDeviceForCamera(camera);
    
    if (device != null) {
      // Use the stored date format for this camera, or default to yyyy_MM_dd
      final cameraDateFormat = widget.cameraDateFormats?[camera];
      final selectedDayFormatted = cameraDateFormat ?? DateFormat('yyyy_MM_dd').format(widget.selectedDate);
      
      final recordingUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/$selectedDayFormatted/$recording';
      
      print('[MultiWatch] Loading recording for ${camera.name}: $recordingUrl (format: ${cameraDateFormat ?? 'default'})');
      
      setState(() {
        _hasError[camera] = false;
        _errorMessages[camera] = '';
      });
      
      final player = _players[camera];
      if (player != null) {
        try {
          player.open(Media(recordingUrl), play: true); // Otomatik başlatma
        } catch (e) {
          print('[MultiWatch] Error loading recording for ${camera.name}: $e');
          setState(() {
            _hasError[camera] = true;
            _errorMessages[camera] = 'Error loading recording: $e';
          });
        }
      }
    } else {
      print('[MultiWatch] No device found for camera: ${camera.name}');
      setState(() {
        _hasError[camera] = true;
        _errorMessages[camera] = 'Device not found for camera';
      });
    }
  }
  
  void _playAll() {
    for (final player in _players.values) {
      player.play();
    }
  }
  
  void _pauseAll() {
    for (final player in _players.values) {
      player.pause();
    }
  }
  
  void _stopAll() {
    for (final player in _players.values) {
      player.stop();
    }
  }
  
  // Seek all players to a specific position
  void _seekAll(Duration position) {
    _isSeeking = true;
    for (final player in _players.values) {
      player.seek(position);
    }
    setState(() {
      _syncPosition = position;
    });
    // Allow position updates after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _isSeeking = false;
    });
  }
  
  // Skip forward/backward all players
  void _skipAll(int seconds) {
    final newPosition = _syncPosition + Duration(seconds: seconds);
    final clampedPosition = newPosition < Duration.zero 
        ? Duration.zero 
        : (newPosition > _syncDuration ? _syncDuration : newPosition);
    _seekAll(clampedPosition);
  }
  
  // Toggle play/pause for all players
  void _togglePlayPause() {
    if (_isSyncPlaying) {
      _pauseAll();
    } else {
      _playAll();
    }
  }
  
  // Format duration to string
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
  
  @override
  void dispose() {
    // Tüm player'ları temizle
    for (final player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraCount = widget.cameraRecordings.length;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Toplu İzleme - ${DateFormat('dd/MM/yyyy').format(widget.selectedDate)}'),
        automaticallyImplyLeading: true, // Sadece geri butonu göster
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Tümünü Oynat',
            onPressed: _playAll,
          ),
          IconButton(
            icon: const Icon(Icons.pause),
            tooltip: 'Tümünü Duraklat',
            onPressed: _pauseAll,
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            tooltip: 'Tümünü Durdur',
            onPressed: _stopAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // Video grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildPlayersGrid(cameraCount),
            ),
          ),
          
          // Synchronized control bar at bottom
          _buildSyncControlBar(),
        ],
      ),
    );
  }
  
  // Build the synchronized control bar
  Widget _buildSyncControlBar() {
    final progress = _syncDuration.inMilliseconds > 0
        ? _syncPosition.inMilliseconds / _syncDuration.inMilliseconds
        : 0.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seek bar
            Row(
              children: [
                // Current position
                Text(
                  _formatDuration(_syncPosition),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                
                // Seek slider
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.primaryOrange,
                      inactiveTrackColor: Colors.grey[600],
                      thumbColor: AppTheme.primaryOrange,
                      overlayColor: AppTheme.primaryOrange.withOpacity(0.2),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (value) {
                        final newPosition = Duration(
                          milliseconds: (value * _syncDuration.inMilliseconds).round(),
                        );
                        _seekAll(newPosition);
                      },
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                // Total duration
                Text(
                  _formatDuration(_syncDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Skip backward 30s
                IconButton(
                  icon: const Icon(Icons.replay_30, color: Colors.white, size: 28),
                  tooltip: '30 saniye geri',
                  onPressed: () => _skipAll(-30),
                ),
                
                // Skip backward 10s
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
                  tooltip: '10 saniye geri',
                  onPressed: () => _skipAll(-10),
                ),
                
                const SizedBox(width: 16),
                
                // Play/Pause button
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isSyncPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                    tooltip: _isSyncPlaying ? 'Tümünü Duraklat' : 'Tümünü Oynat',
                    onPressed: _togglePlayPause,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Skip forward 10s
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
                  tooltip: '10 saniye ileri',
                  onPressed: () => _skipAll(10),
                ),
                
                // Skip forward 30s
                IconButton(
                  icon: const Icon(Icons.forward_30, color: Colors.white, size: 28),
                  tooltip: '30 saniye ileri',
                  onPressed: () => _skipAll(30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlayersGrid(int cameraCount) {
    // Ekran boyutuna göre optimal grid düzenini belirle
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    int crossAxisCount;
    double childAspectRatio;
    
    if (cameraCount == 1) {
      // Tek kamera - tam ekran
      crossAxisCount = 1;
      childAspectRatio = isLandscape ? 16 / 9 : 9 / 16;
    } else if (cameraCount == 2) {
      // İki kamera - yan yana veya alt alta
      crossAxisCount = isLandscape ? 2 : 1;
      childAspectRatio = 16 / 9;
    } else if (cameraCount <= 4) {
      // 3-4 kamera - 2x2 grid
      crossAxisCount = 2;
      childAspectRatio = 16 / 9;
    } else if (cameraCount <= 6) {
      // 5-6 kamera - 3x2 veya 2x3
      crossAxisCount = isLandscape ? 3 : 2;
      childAspectRatio = 16 / 9;
    } else if (cameraCount <= 9) {
      // 7-9 kamera - 3x3
      crossAxisCount = 3;
      childAspectRatio = 16 / 9;
    } else if (cameraCount <= 12) {
      // 10-12 kamera - 4x3
      crossAxisCount = 4;
      childAspectRatio = 16 / 9;
    } else {
      // 12+ kamera - dense grid
      crossAxisCount = isLandscape ? 5 : 4;
      childAspectRatio = 16 / 9;
    }
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: cameraCount,
      itemBuilder: (context, index) {
        final camera = widget.cameraRecordings.keys.elementAt(index);
        final recording = widget.cameraRecordings[camera]!;
        
        return _buildVideoPlayer(camera, recording);
      },
    );
  }
  
  Widget _buildVideoPlayer(Camera camera, String recording) {
    final controller = _controllers[camera];
    final player = _players[camera];
    final isBuffering = _isBuffering[camera] ?? false;
    final hasError = _hasError[camera] ?? false;
    final errorMessage = _errorMessages[camera] ?? '';
    final cameraCount = widget.cameraRecordings.length;
    
    // Kamera sayısına göre font boyutu ayarla
    double titleFontSize = cameraCount <= 4 ? 14 : (cameraCount <= 9 ? 12 : 10);
    double iconSize = cameraCount <= 4 ? 20 : (cameraCount <= 9 ? 16 : 14);
    
    if (controller == null || player == null) {
      return _buildErrorCard(camera, 'Player not initialized');
    }
    
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: cameraCount <= 4 ? 4 : 2, // Daha az kamera = daha yüksek elevation
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kamera başlığı
          Container(
            padding: EdgeInsets.all(cameraCount <= 4 ? 8.0 : 6.0),
            color: AppTheme.primaryBlue,
            child: Row(
              children: [
                Icon(Icons.videocam, color: Colors.white, size: iconSize),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    camera.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Recording format indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    recording.toLowerCase().endsWith('.m3u8') ? 'M3U8' : 'MKV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFontSize - 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Video oynatıcı
          Expanded(
            child: Stack(
              children: [
                // Video Widget
                Container(
                  color: Colors.black,
                  child: Video(
                    controller: controller,
                    fill: Colors.black,
                    controls: null,
                  ),
                ),
                
                // Buffering indicator
                if (isBuffering)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                
                // Error overlay
                if (hasError)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Mini controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            (_isPlaying[camera] ?? false) ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            if (_isPlaying[camera] ?? false) {
                              player.pause();
                            } else {
                              player.play();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => player.stop(),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => _openFullScreen(camera, recording),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Kayıt bilgisi
          Container(
            padding: const EdgeInsets.all(4.0),
            color: Colors.grey[100],
            child: Text(
              recording.split('/').last.split('_').first,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorCard(Camera camera, String error) {
    return Card(
      child: Container(
        color: Colors.grey[100],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              camera.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(fontSize: 12, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  void _openFullScreen(Camera camera, String recording) {
    final controller = _controllers[camera];
    final player = _players[camera];
    
    if (controller != null && player != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: Text(camera.name),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            body: Stack(
              children: [
                Center(
                  child: Video(
                    controller: controller,
                    fill: Colors.black,
                    controls: null,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoControls(
                    player: player,
                    showFullScreenButton: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
