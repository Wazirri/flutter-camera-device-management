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

  const MultiWatchScreen({
    Key? key,
    required this.cameraRecordings,
    required this.selectedDate,
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
  
  @override
  void initState() {
    super.initState();
    _initializePlayers();
  }
  
  void _initializePlayers() {
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
      final selectedDayFormatted = DateFormat('yyyy_MM_dd').format(widget.selectedDate);
      final recordingUrl = 'http://${device.ipv4}:8080/Rec/${camera.name}/$selectedDayFormatted/$recording';
      
      print('[MultiWatch] Loading recording for ${camera.name}: $recordingUrl');
      
      setState(() {
        _hasError[camera] = false;
        _errorMessages[camera] = '';
      });
      
      final player = _players[camera];
      if (player != null) {
        try {
          player.open(Media(recordingUrl), play: false); // Otomatik başlatma
        } catch (e) {
          setState(() {
            _hasError[camera] = true;
            _errorMessages[camera] = 'Error loading recording: $e';
          });
        }
      }
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
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _buildPlayersGrid(cameraCount),
      ),
    );
  }
  
  Widget _buildPlayersGrid(int cameraCount) {
    // Grid düzenini belirle
    int crossAxisCount;
    if (cameraCount == 1) {
      crossAxisCount = 1;
    } else if (cameraCount <= 4) {
      crossAxisCount = 2;
    } else if (cameraCount <= 9) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 4;
    }
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 16 / 9, // Video aspect ratio
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
    
    if (controller == null || player == null) {
      return _buildErrorCard(camera, 'Player not initialized');
    }
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kamera başlığı
          Container(
            padding: const EdgeInsets.all(8.0),
            color: AppTheme.primaryBlue,
            child: Row(
              children: [
                const Icon(Icons.videocam, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    camera.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
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
